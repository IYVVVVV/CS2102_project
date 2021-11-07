-- trigger such that employees can only join future meetings
create or replace function f_check_join_only_future_meeting()
returns trigger as $$
declare
    num_participant INT;
begin
    if NEW.jdate > now()::date OR (NEW.jdate = now()::date and NEW.jtime > now()::time) then
        return NEW;
    end if;
    raise exception 'Join failed. Can only join future meetings.';
    return NULL;
end;
$$ LANGUAGE plpgsql;

create trigger check_join_only_future_meeting
before insert or update on Joins
for each row
execute function f_check_join_only_future_meeting();


-- check if an employee is resigned
CREATE OR REPLACE FUNCTION is_resigned(IN _eid INT)
RETURNS BOOLEAN AS $$
DECLARE
    rdate DATE;
BEGIN 
    SELECT resigned_date INTO rdate FROM Employees WHERE Employees.eid=_eid;
    RETURN rdate is NOT NULL AND rdate<=now()::date;
END;
$$ LANGUAGE plpgsql;



-- trigger such that only department with no current employees and no rooms can be deleted
create or replace function f_check_department_deletion_condition()
returns trigger as $$
declare 
    emps record;
begin
    FOR emps IN SELECT * FROM Employees WHERE Employees.did=OLD.did LOOP
        IF not is_resigned(emps.eid) THEN
            RAISE exception 'Remove failed. Some employees in this department % is not removed yet', _did;
        END IF;
    END LOOP;
    IF (SELECT count(*) FROM Meeting_Rooms WHERE Meeting_Rooms.did=_did ) <> 0 THEN
        RAISE exception 'Remove failed. Delete all meeting rooms inside department % before deleting the department!', _did;
    END IF;
    return OLD;
end;
$$ LANGUAGE plpgsql;

create trigger check_department_deletion_condition
before delete on Departments
for each row
execute function f_check_department_deletion_condition();


/* 
 * Basic_1: add a new department
 * input: 
 * output:
 */
CREATE OR REPLACE FUNCTION add_department (IN _did INT, IN _name VARCHAR(100))
RETURNS INT AS $$
declare 
    current_did int;
begin
    select did into current_did from Departments where did = _did;
    if current_did is not NULL then
        raise exception 'Add failed. There is already a department with such id.';
    end if;

	INSERT INTO Departments VALUES (_did, _name);
    return 0;
end;
$$ LANGUAGE plpgsql;


/* 
 * Basic_2: remove a department
 * input: 
 * output:
 */
CREATE OR REPLACE function remove_department (IN _did INT)
RETURNS INT AS $$
declare 
    current_did int;
    emps record;
begin
    select did into current_did from Departments where did = _did;
    if current_did is NULL then
        raise exception 'Remove failed. There is no department with such id.';
    end if;
    DELETE FROM Departments WHERE Departments.did = _did;
    return 0;
end;
$$ LANGUAGE plpgsql;

/* 
 * Working
 * Basic_3: add a new meeting room
 * input: 
 * output:
 */
CREATE OR REPLACE FUNCTION add_room( _room_floor INTEGER, _room_num INTEGER, _room_name varchar(100), _room_capacity INTEGER, _did INTEGER, _manager_id INTEGER)
RETURNS INT AS $$	
DECLARE
	manager_did INT;
BEGIN
	-- check did is valid
	IF NOT EXISTS (SELECT 1 FROM Departments d WHERE d.did = _did) THEN 
		RAISE EXCEPTION 'Input did is not a valid did';
	END IF;
	-- check manager is valid
	IF NOT EXISTS (SELECT 1 FROM Managers m WHERE m.eid = _manager_id) THEN 
		RAISE EXCEPTION 'Input eid is not a manager id';
	END IF;
	-- check manager is in the department
	SELECT did INTO manager_did FROM Managers NATURAL JOIN Employees WHERE eid = _manager_id;
	IF (_did <> manager_did) THEN
		RAISE EXCEPTION 'Manager from different department cannot change meeting room capacity.';
	END IF;
	-- update the Meeting_Rooms and Updates tables
	INSERT INTO Meeting_Rooms VALUES (_room_num, _room_floor, _room_name, _did);
	INSERT INTO Updates (manager_id, room, ufloor, udate, new_cap) VALUES (_manager_id, _room_num, _room_floor, now()::DATE, _room_capacity);
	RETURN 0;
END	
$$ LANGUAGE plpgsql;


/* 
 * Working!
 * Basic_4: change the capacity of the room
 * input: 
 * output:
 */
CREATE OR REPLACE FUNCTION change_capacity(_manager_id INTEGER, _room_num INTEGER, _room_floor INTEGER, _new_capacity INTEGER, _update_date DATE)
RETURNS INT AS $$
DECLARE
	manager_did INT;
	room_did INT;
    num_participant INT;
    session record;
BEGIN
	-- check room exists
	IF NOT EXISTS (SELECT 1 FROM Updates u WHERE u.room = _room_num AND u.ufloor = _room_floor) THEN 
		RAISE EXCEPTION 'The input room does not exist.';
	END IF;
	
	-- check manager is valid
	IF NOT EXISTS (SELECT 1 FROM Managers m WHERE m.eid = _manager_id) THEN 
		RAISE EXCEPTION 'Input eid is not a manager id.';
	END IF;
	
	-- check manager is in the department
	SELECT did INTO room_did FROM Meeting_Rooms r WHERE r.room = _room_num AND r.mfloor = _room_floor;
	SELECT did INTO manager_did FROM Managers NATURAL JOIN Employees WHERE eid = _manager_id;
	IF (room_did <> manager_did) THEN
		RAISE EXCEPTION 'Manager from different department cannot change meeting room capacity.';
	END IF;
	
	-- check future meetings
	IF _update_date < now()::DATE THEN
		RAISE EXCEPTION 'The update date cannot earlier than today';
	END IF;
	
	-- update the Updates table
	insert into Updates(manager_id, room, ufloor, udate, new_cap)
        values(_manager_id, _room_num, _room_floor, _update_date, _new_capacity);
	
	
    -- remove affected joins
    for session in select * from Sessions where Sessions.sdate > _update_date
                                            and Sessions.sfloor = _room_floor and Sessions.room = _room_num
    LOOP
        select count(*) into num_participant
        from Joins as j
        where j.room = session.room and j.jfloor = session.sfloor
            and j.jtime = session.stime and j.jdate = session.sdate;
        if num_participant > _new_capacity then
            delete from Joins where Joins.room = session.room and Joins.jfloor = session.sfloor
                                and Joins.jtime = session.stime and Joins.jdate = session.sdate;
        end if;
    end LOOP;
	
    -- remove affected sessions
    delete from Sessions where (
        select count(*) from Joins as j where j.room = Sessions.room and j.jfloor = Sessions.sfloor
            and j.jtime = Sessions.stime and j.jdate = Sessions.sdate
        ) = 0;
    return 0;
END
$$ LANGUAGE plpgsql;


/* 
 * Basic_5: add a new employee
 * input: ename, contact_numbers, kind, did
 * contact_number is a array of length 8 strings, e.g. '{"12345678", "12345679"}'
 * output: 0 success
 */
create or replace function add_employee(_ename varchar(50), _contact_numbers char(8)[], _kind varchar(10), _did int)
returns int as $$
declare
    current_eid int;
    current_email varchar(50) := '_-1@gmail.com'; -- dummy email first
    contact_number char(8);
begin
    -- check kind
    if (_kind <> 'junior' and _kind <> 'senior' and _kind <> 'manager') then
        raise exception 'Add failed. Invalid employee job kind, should be junior, senior or manager.';
    end if;
    -- check contact numbers
    if _contact_numbers is NULL then
        raise exception 'Add failed. At least one contact number is required.';
    end if;

    insert into Employees(ename, email, resigned_date, did) values (_ename, current_email, NULL, _did) returning eid into current_eid;
    current_email := concat(replace(_ename, ' ', ''), '_', current_eid::text, '@gmail.com');
    update Employees set email = current_email where eid = current_eid;

    case _kind
        when 'junior' then
            insert into Juniors values (current_eid);
        when 'senior' then
            insert into Bookers values (current_eid);
            insert into Seniors values (current_eid);
        else -- manager
            insert into Bookers values (current_eid);
            insert into Managers values (current_eid);
    end case;

    -- update Contacts table
    foreach contact_number in array _contact_numbers
    loop
        insert into Contacts values (current_eid, contact_number);
    end loop;

    return 0;
end;
$$ language plpgsql;


/* 
 * Basic_6: remove a employee
 * input: eid, date
 * this function will set the resigned_date to be non-null value
 * date is the last day of work, thus the employee still needs to declare health for on this date
 * output: 0 success
 */
create or replace function remove_employee (_eid int, _resigned_date date)
returns int as $$
declare
    current_eid int;
    num_records int := 0;
    old_resigned_date date;
    session_to_remove record;
begin
    select eid from Employees where eid = _eid into current_eid;
    if current_eid is null then
        raise exception 'Remove failed. No employee with the given eid.';
    end if;

    select resigned_date into old_resigned_date from Employees where eid = _eid;
    if old_resigned_date is not null then
        raise exception 'Remove failed. The employee has been removed before.';
    end if;
        
    update Employees set resigned_date = _resigned_date where eid = _eid;
    update Employees set did = NULL where eid = _eid;
    
    -- remove his future booking session ans all joins
    -- remove joins first
    FOR session_to_remove IN SELECT * FROM Sessions WHERE Sessions.booker_id=_eid and Sessions.sdate > _resigned_date
    LOOP
        delete from Joins as j where j.room = session_to_remove.room and j.jfloor = session_to_remove.sfloor 
                                and j.jtime = session_to_remove.stime and j.jdate = session_to_remove.sdate;
    END LOOP;
    -- remove sessions then
    delete from Sessions where Sessions.booker_id = _eid and Sessions.sdate > _resigned_date;

    --remove his future joins
    delete from Joins where Joins.eid = _eid and Joins.jdate > _resigned_date;

    --rollback approval for future meetings if eid is the manager who approved the meeting
    update Sessions set manager_id = NULL where manager_id = _eid and Sessions.sdate > _resigned_date;
    return 0;

end;
$$ language plpgsql;


/* 
 * Core_1: search for available rooms
 * input: 
 * output:
 */
CREATE OR REPLACE FUNCTION search_room (_capacity INTEGER, _date DATE, _start_hour TIME, _end_hour TIME)
RETURNS TABLE(room_number INTEGER, floor_number INTEGER, department_id INTEGER, capacity INTEGER) AS $$
DECLARE
	
BEGIN
	RETURN QUERY
	SELECT DISTINCT r.room, r.mfloor, r.did, u.new_cap
	FROM Meeting_Rooms r 
	JOIN Updates u 
	ON r.room = u.room AND r.mfloor = u.ufloor
	, Sessions s
	WHERE u.new_cap >= _capacity
	AND NOT (s.room = r.room AND s.sfloor = r.mfloor AND s.sdate = _date AND s.stime >= _start_hour AND s.stime < _end_hour);
END;
$$ LANGUAGE plpgsql;


/* 
 * WORKING RIGHT NOW
 * Core_2: book a given room
 * input: 
 * output:
 */
 
CREATE OR REPLACE PROCEDURE book_room (_room_num INTEGER, _room_floor INTEGER, _start_hour TIME, _end_hour TIME, _session_date DATE, _booker_id INTEGER) AS $$
DECLARE
	current_hour TIME := _start_hour;
	each_hour TIME[];
	var_hour TIME;
	start_hour_ok INTEGER := 0;
	end_hour_ok INTEGER := 0;
	has_been_booked INTEGER := 0;
BEGIN
	-- check id in booker table
	IF NOT EXISTS (SELECT 1 FROM Bookers b WHERE b.eid = _booker_id) THEN 
		RAISE EXCEPTION 'The booker is not authorized to book a room.';
	END IF;
	
	-- check future meetings
	IF _session_date < now()::DATE OR (_session_date = now()::DATE AND _start_hour < now()::TIME) THEN
		RAISE EXCEPTION 'A booking can only be made for future meetings';
	END IF;
	
	-- check room exists
	IF NOT EXISTS (SELECT 1 FROM Updates u WHERE u.room = _room_num AND u.ufloor = _room_floor) THEN 
		RAISE EXCEPTION 'The input room does not exist.';
	END IF;
	
	-- check for start and end hour
	each_hour := '{00:00, 01:00, 02:00, 03:00, 04:00, 05:00, 06:00,
                  07:00, 08:00, 09:00, 10:00, 11:00, 12:00, 
                  13:00, 14:00, 15:00, 16:00, 17:00, 18:00,
                  19:00, 20:00, 21:00, 22:00, 23:00, 24:00}'::TIME[];
	FOREACH var_hour IN ARRAY each_hour LOOP
		IF var_hour = _start_hour THEN
			start_hour_ok := 1;
		END IF;
		IF var_hour = _end_hour THEN
			end_hour_ok := 1;
		END IF;
	END LOOP;
	IF start_hour_ok = 0 OR end_hour_ok = 0 THEN
		RAISE EXCEPTION	'The input start hour or end hour must be full hour.';
	END IF;
	
	-- check booker has not resigned
	IF is_resigned(_booker_id) THEN 
        RAISE EXCEPTION 'Booker has resigned!';
    END IF;
	
	-- check employee does not have fever
	IF (SELECT fever FROM Health_declarations WHERE eid = _booker_id AND hdate = now()::DATE) THEN
		RAISE EXCEPTION 'Booker is having a fever and cannot book!';
	END IF;
	
	-- check the session has not been booked
	SELECT 1 INTO has_been_booked
	FROM Sessions s 
	WHERE s.room = _room_num AND s.sfloor = _room_floor AND s.sdate = _session_date AND s.stime >= _start_hour AND s.stime < _end_hour;
	IF has_been_booked = 1 THEN
		RAISE EXCEPTION 'The session has been booked!';
	END IF;
	
	-- insert into Sessions
	WHILE current_hour < _end_hour LOOP
		INSERT INTO Sessions VALUES (_room_num, _room_floor, current_hour, _session_date, _booker_id, NULL);
		current_hour := current_hour + '1 hour';
	END LOOP;
	
	-- booker immediately joins
	CALL JoinMeeting(_room_floor, _room_num, _session_date, _start_hour, _end_hour, _booker_id);
END;
$$ LANGUAGE plpgsql;

/* 
 * WORKING
 * Core_3: remove booking of a given room
 * input: 
 * output:
 */
CREATE OR REPLACE PROCEDURE unbook_room (_room_num INTEGER, _room_floor INTEGER, _start_hour TIME, _end_hour TIME, _session_date DATE, _unbooker_id INTEGER) AS $$
DECLARE
	current_hour TIME := _start_hour;
	unbooker_ok INTEGER := 1;
	start_hour_ok INTEGER := 0;
	end_hour_ok INTEGER := 0;
	each_hour TIME[];
	var_hour TIME;
	booker_eid INTEGER;
	session record;
BEGIN
	-- check room exists
	IF NOT EXISTS (SELECT 1 FROM Updates u WHERE u.room = _room_num AND u.ufloor = _room_floor) THEN 
		RAISE EXCEPTION 'The input room does not exist.';
	END IF;
	
	-- check for start and end hour
	each_hour := '{00:00, 01:00, 02:00, 03:00, 04:00, 05:00, 06:00,
                  07:00, 08:00, 09:00, 10:00, 11:00, 12:00, 
                  13:00, 14:00, 15:00, 16:00, 17:00, 18:00,
                  19:00, 20:00, 21:00, 22:00, 23:00, 24:00}'::TIME[];
	FOREACH var_hour IN ARRAY each_hour LOOP
		IF var_hour = _start_hour THEN
			start_hour_ok := 1;
		END IF;
		IF var_hour = _end_hour THEN
			end_hour_ok := 1;
		END IF;
	END LOOP;
	IF start_hour_ok = 0 OR end_hour_ok = 0 THEN
		RAISE EXCEPTION	'The input start hour or end hour must be full hour.';
	END IF;
	
	-- check the session specified exists and unbooker_id is book_id
	WHILE current_hour < _end_hour LOOP
		SELECT s.booker_id INTO booker_eid FROM Sessions s WHERE s.room = _room_num AND s.sfloor = _room_floor AND s.sdate = _session_date AND s.stime = current_hour;
		IF booker_eid IS NULL THEN 
			RAISE EXCEPTION 'The session does not exist';
		END IF;
		IF _unbooker_id <> booker_eid THEN 
			unbooker_ok := 0;
		END IF;
		current_hour := current_hour + '1 hour';
	END LOOP;
	IF unbooker_ok = 0 THEN
		RAISE EXCEPTION 'The unbooker and booker must be the same person';
	END IF;
	 
	-- remove affected joins
    FOR session IN SELECT * FROM Sessions s where s.sfloor = _room_floor AND s.room = _room_num AND s.sdate = _session_date AND s.stime >= _start_hour AND s.stime < _end_hour
    LOOP
        DELETE FROM Joins j 
		WHERE j.room = session.room
		AND j.jfloor = session.sfloor
        AND j.jtime = session.stime
		AND j.jdate = session.sdate;
    END LOOP;
	
	-- perform deletion
	DELETE FROM Sessions s
	WHERE s.room = _room_num
	AND s.sfloor = _room_floor
	AND s.sdate = _session_date
	AND s.stime >= _start_hour
	AND s.stime < _end_hour;
END;
$$ LANGUAGE plpgsql;

/* 
 * Core_4: join a booked meeting room
 * input: floor_number, room_number, meeting_date, start_hour, end_hour, eid
 * output: null cause a procedure
 */
CREATE OR REPLACE PROCEDURE JoinMeeting (IN floor_number INT, IN room_number INT, IN meeting_date Date, IN start_hour TIME, IN end_hour TIME, IN id INT) AS $$
DECLARE 
    temp TIME := start_hour;
    each_hour TIME[];
	var_hour TIME;
	start_hour_ok INTEGER := 0;
	end_hour_ok INTEGER := 0;
    existing_eid INT;
    resigned DATE;
    fever_id INT;
    close_contact INT;
    existing_room INT;
    session_eid INT;
    joined_id INT; 
    meeting_room INT;
    capacity INT :=0;
    number_participants INT :=0;
BEGIN
    -- check whether start and end hour are full hour
	each_hour := '{00:00, 01:00, 02:00, 03:00, 04:00, 05:00, 06:00,
                  07:00, 08:00, 09:00, 10:00, 11:00, 12:00, 
                  13:00, 14:00, 15:00, 16:00, 17:00, 18:00,
                  19:00, 20:00, 21:00, 22:00, 23:00, 24:00}'::TIME[];
	FOREACH var_hour IN ARRAY each_hour LOOP
		IF var_hour = start_hour THEN
			start_hour_ok := 1;
		END IF;
		IF var_hour = end_hour THEN
			end_hour_ok := 1;
		END IF;
	END LOOP;
	IF start_hour_ok = 0 OR end_hour_ok = 0 THEN
		RAISE EXCEPTION	'The input start hour or end hour must be full hour.';
	END IF;
	
    -- check whether start time is before end time
    IF start_hour > end_hour THEN
        raise exception 'Join failed because start time is after end time.';
    END IF;
	
    -- check whether the employee with eid exists
    SELECT eid INTO existing_eid FROM Employees WHERE eid = id;
    IF existing_eid IS NULL THEN
        raise exception 'Join Failed. There is no employee with such id.';
    END IF;
	
    -- check whether the employee has resigned
    SELECT resigned_date INTO resigned FROM Employees WHERE eid = id;
    IF resigned IS NOT NULL AND meeting_date > resigned THEN
        raise exception 'Join failed. The employee has resigned.';
    END IF;
	
    -- check whether the employee has a fever
    SELECT h.eid INTO fever_id FROM Health_declarations h WHERE h.eid = id AND h.hdate = now()::date AND fever = true;
    IF fever_id IS NOT NULL THEN
        raise exception 'Join failed. The employee has a fever.';
    END IF; 
	
    -- *check whether the employee has close contact in the last 7 days
    SELECT COUNT(*) INTO close_contact FROM Close_Contacts WHERE eid = id AND affect_date = meeting_date;
    IF close_contact <> 0 THEN
        raise exception 'Join failed. The employee had a close contact with someone having a fever.';
    END IF;
    
    -- Join
    WHILE temp < end_hour LOOP
        -- check whether the session exists
        SELECT room INTO existing_room FROM Sessions WHERE room = room_number AND sfloor = floor_number AND stime = temp AND sdate = meeting_date;
        IF existing_room IS NULL THEN 
            raise exception 'Join failed. There is no session held at given time, date, room, floor.';
        END IF;
		
        -- check whether the employee has joined any session among the time period already
        SELECT eid INTO joined_id FROM Joins j WHERE j.eid = id AND room = room_number AND jfloor = floor_number AND jtime = temp AND jdate = meeting_date;
        IF joined_id IS NOT NULL THEN
            raise exception 'Join failed. The time period contains some sessions that employee has already joined';
        END IF;
		
        -- check an employee cannot join several sessions at the same time
        SELECT eid INTO session_eid FROM Joins WHERE eid = id AND jtime = temp AND jdate = meeting_date;
        IF session_eid IS NOT NULL THEN
            raise exception 'Join failed. The employee has joined another session held at the same time and date.';
        END IF;
		
        -- check whether all the sesions have been approved
        SELECT room INTO meeting_room FROM Sessions WHERE room = room_number AND sfloor = floor_number AND stime = temp AND sdate = meeting_date AND manager_id IS NULL;
        IF meeting_room IS NULL THEN
            raise exception 'Join failed. The time period contains some sessions that has been approved already.';
        END IF;
		
        -- check if exceede the capacity limits.
        SELECT new_cap INTO capacity FROM Updates WHERE room = meeting_room AND ufloor = floor_number AND udate = (SELECT MAX(udate) FROM Updates WHERE room = meeting_room AND ufloor = floor_number AND udate < meeting_date);
        SELECT COUNT(*) INTO number_participants FROM Joins WHERE room = meeting_room AND jfloor = floor_number AND jtime = temp AND jdate = meeting_date;
        IF number_participants >= capacity THEN
            raise exception 'Join failed. The number of participants has reached the capacity limit of the room';
        END IF;
		
        -- Insert into Joins
        INSERT INTO Joins VALUES (id, room_number, floor_number, temp, meeting_date);
        temp := temp + '1 hour';
    END LOOP;
END;
$$ LANGUAGE plpgsql;


/* 
 * Core_5: leave a booked meeting room
 * input: floor_number, room_number, meeting_date, start_hour, end_hour, eid
 * output: null cause a procedure
 */
CREATE OR REPLACE PROCEDURE LeaveMeeting (IN floor_number INT, IN room_number INT, IN meeting_date Date, IN start_hour TIME, IN end_hour TIME, IN id INT) AS $$
DECLARE 
    temp TIME := start_hour;
    each_hour TIME[];
	var_hour TIME;
	start_hour_ok INTEGER := 0;
	end_hour_ok INTEGER := 0;
    current_eid INT;
    existing_room INT;
    meeting_room INT;
    joined_id INT; 
BEGIN
    -- check whether start and end hour are full hour
	each_hour := '{00:00, 01:00, 02:00, 03:00, 04:00, 05:00, 06:00,
                  07:00, 08:00, 09:00, 10:00, 11:00, 12:00, 
                  13:00, 14:00, 15:00, 16:00, 17:00, 18:00,
                  19:00, 20:00, 21:00, 22:00, 23:00, 24:00}'::TIME[];
	FOREACH var_hour IN ARRAY each_hour LOOP
		IF var_hour = start_hour THEN
			start_hour_ok := 1;
		END IF;
		IF var_hour = end_hour THEN
			end_hour_ok := 1;
		END IF;
	END LOOP;
	IF start_hour_ok = 0 OR end_hour_ok = 0 THEN
		RAISE EXCEPTION	'Leave failed. The input start hour or end hour must be full hour.';
	END IF;

    -- check whether start time is before after time
    IF start_hour > end_hour THEN
    raise exception 'Leave failed. Start time is after end time.';
    END IF;
	
    -- check whether the employee with eid exists
    SELECT eid INTO current_eid FROM Employees WHERE eid = id;
    IF current_eid IS NULL THEN
        raise exception 'Leave Failed. There is no employee with such id.';
    END IF;
	
    -- Leave
    WHILE temp < end_hour LOOP
        -- check whether the session exists
        SELECT room INTO existing_room FROM Sessions WHERE room = room_number AND sfloor = floor_number AND stime = temp AND sdate = meeting_date;
        IF existing_room IS NULL THEN 
            raise exception 'Leave failed. There is no session held at given time, date, room, floor.';
        END IF;
		
        -- check whether the session has been approved
        SELECT room INTO meeting_room FROM Sessions WHERE room = room_number AND sfloor = floor_number AND stime = temp AND sdate = meeting_date AND manager_id IS NULL;
        IF meeting_room IS NULL THEN
            raise exception 'Leave failed. The meeting has been approved already.';
        END IF;
		
        -- check whether the employee has left the meeting or did not join
        SELECT eid INTO joined_id FROM Joins j WHERE j.eid = id AND room = room_number AND jfloor = floor_number AND jtime = temp AND jdate = meeting_date;
        IF joined_id IS NULL THEN
            raise exception 'Leave failed. The employee has already left the meeting or did not join the meeting';
        END IF;
		
        -- Delete from Joins
        DELETE FROM Joins WHERE eid = id AND room = room_number AND jfloor = floor_number AND jtime = temp AND jdate = meeting_date;
        temp := temp + '1 hour';
    END LOOP;
END;
$$ LANGUAGE plpgsql;

/* 
 * Core_6: approve a booking
 * input: 
 * output:
 */
CREATE OR REPLACE function approve_meeting (IN floor_num INT, room_num INT, IN date DATE, IN start_hour TIME, IN end_hour TIME, IN booker_eid INT, IN approve_eid INT, IN isApproved BOOLEAN) 
RETURNS INT AS $$
DECLARE 
	meid INT; 
	mng_did INT; 
	expect_did INT; 
	rdate DATE; 
	temp TIME;
	booker_count INT; 
	bid INT;
	start_hour_ok INT := 0;
	end_hour_ok INT := 0;
	each_hour TIME[];
BEGIN
	-- check is manager
    SELECT eid INTO meid From Managers WHERE eid=approve_eid;
    IF meid IS NULL THEN
		RAISE 'The given eid % is not a manager!', approve_eid;
	END IF;
	
	-- get manager department id
	SELECT did INTO mng_did FROM Employees WHERE eid=approve_eid;
	
	-- check whether manager has resigned 
	IF is_resigned(approve_eid) THEN 
        RAISE 'Manager % is resigned!', approve_eid;
    END IF;
    
	-- get room department id and check room exists or not 
    SELECT did INTO expect_did FROM Meeting_Rooms WHERE mfloor=floor_num and Room=room_num;
	IF expect_did IS NULL THEN
		RAISE 'The given room % in % floor does not exist!', room_num, floor_num;
	END IF;
	
	-- check for start and end hour
	each_hour := '{00:00, 01:00, 02:00, 03:00, 04:00, 05:00, 06:00,
                  07:00, 08:00, 09:00, 10:00, 11:00, 12:00, 
                  13:00, 14:00, 15:00, 16:00, 17:00, 18:00,
                  19:00, 20:00, 21:00, 22:00, 23:00, 24:00}'::TIME[];
	temp := start_hour;
	FOREACH temp IN ARRAY each_hour LOOP
		IF temp = start_hour THEN
			start_hour_ok := 1;
		END IF;
		IF temp = end_hour THEN
			end_hour_ok := 1;
		END IF;
	END LOOP;
	IF start_hour_ok = 0 OR end_hour_ok = 0 THEN
		RAISE EXCEPTION	'The input start hour or end hour must be full hour.';
	END IF;
	
	-- check future meetings
	IF date < now()::DATE OR (date = now()::DATE AND start_hour < now()::TIME) THEN
		RAISE EXCEPTION 'An approval can only be made for future meetings';
	END IF;
	
	-- check room department and manager department
    IF mng_did<>expect_did THEN
        RAISE 'The given manager % is not in the same department as the meeting room.', approve_eid;
    END IF;
	
	-- check session exists and booker is correct 
	temp := start_hour;
	WHILE temp< end_hour LOOP  
        SELECT booker_id INTO bid FROM Sessions WHERE room=room_num AND sfloor=floor_num AND stime=temp AND sdate=date;
		IF bid IS NULL THEN
			RAISE EXCEPTION 'Session does not exist';
		END IF;
        IF bid <> booker_eid THEN 
            RAISE EXCEPTION 'The booker for the meeting is not correct.';
        END IF;
        temp:=temp+'1 hour';
    END LOOP;
	
	-- check already approved
	temp := start_hour;
    WHILE temp < end_hour LOOP  
        SELECT booker_id INTO bid FROM Sessions WHERE room = room_num AND sfloor = floor_num AND stime = temp AND sdate = date AND manager_id IS NOT NULL;
        IF bid IS NOT NULL THEN
            RAISE EXCEPTION 'The room % in floor % is already approved at time % and date %', room_num, floor_num, temp, date;
        END IF;
        temp := temp+ '1 hour';
    END LOOP;
    
    IF isApproved THEN
        temp := start_hour;
        WHILE temp < end_hour LOOP
            INSERT INTO Sessions VALUES (room_num, floor_num, temp, date, booker_eid, approve_eid)
            ON CONFLICT(room, sfloor, stime, sdate) DO UPDATE SET manager_id = approve_eid;
            temp:= temp +'1 hour';
        END LOOP;
	ELSE    
        temp := start_hour;
        WHILE temp < end_hour LOOP
            DELETE FROM Joins WHERE room=room_num AND jfloor=floor_num AND jdate=date AND jtime=temp;
            temp:= temp +'1 hour';
        END LOOP;
        temp:=start_hour;
        WHILE temp<end_hour LOOP
            DELETE FROM Sessions WHERE room=room_num AND sfloor=floor_num AND sdate=date AND stime=temp;
            temp:= temp +'1 hour';
        END LOOP;
    END IF;
    return 0;
END;
$$ LANGUAGE plpgsql;



/* 
 * Health_1: used for daily declaration of temperature
 * input: 
 * output:
 */
CREATE OR REPLACE FUNCTION declare_health (IN _eid INT, IN ddate DATE, IN temp FLOAT(2))
RETURNS INT AS $$
DECLARE 
	fever BOOLEAN;
BEGIN
	IF _eid NOT IN (SELECT eid FROM Employees)  THEN
		RAISE 'The given eid % does not exist!', _eid
		USING HINT = 'Please check the eid';
	END IF;
	IF is_resigned(_eid) THEN
		RAISE 'Empoloyee % is resigned!', _eid
		USING HINT = 'Please check the eid';
	END IF;
	fever = CASE
		WHEN temp>=37.5 THEN TRUE
		WHEN temp <37.5 THEN FALSE
	END;
	INSERT INTO Health_declarations VALUES (_eid, ddate, temp, fever);
    return 0;
END;
$$ LANGUAGE plpgsql;


/* 
 * Health_2: used for contact tracing
 * input: 
 * output: a list of eid as close contacts
 * by default, we assume the date is today, and today's meeting
 */
CREATE OR REPLACE FUNCTION contact_tracing (IN _eid INT)
RETURNS TABLE (close_contact_eid INT)
AS $$
declare
    current_eid int;
    num_records int := 0;
    _affected_date date;
    session_to_remove record;
    close_contact_eid int;
    close_contact_session_to_remove record;
begin
    -- check eid is valid
    select Employees.eid from Employees where Employees.eid = _eid into current_eid;
    if current_eid is null then
        raise exception 'Contact tracing failed. No employee with the given eid.';
    end if;
	-- check eid is having fever
    select count(*) into num_records from Health_declarations
        where Health_declarations.eid = _eid and hdate = now()::date;
    if num_records = 0 then
        raise exception 'Contact tracing failed. No temperature declared today';
    end if;

    if not (select fever from Health_declarations where Health_declarations.eid = _eid and hdate = now()::date) then
        raise notice 'The employee does not have fever today.';
        return;
    end if;
	-- if have fever, perform contact tracing
	-- for eid himself
    -- remove his future bookings and other's join
    -- remove joins first
    FOR session_to_remove IN SELECT * FROM Sessions WHERE Sessions.booker_id=_eid and Sessions.sdate > now()::date
    LOOP
        delete from Joins as j where j.room = session_to_remove.room and j.jfloor = session_to_remove.sfloor 
                                and j.jtime = session_to_remove.stime and j.jdate = session_to_remove.sdate;
    END LOOP;
    -- remove sessions then
    delete from Sessions where Sessions.booker_id = _eid and Sessions.sdate > now()::date;

    -- remove his future joins
    delete from Joins where Joins.eid = _eid and Joins.jdate > now()::date;

    -- find his close contacts (same approved meetings in D-3 to D)
    For close_contact_eid in (
        select jo.eid
        from Sessions as ss, Joins as jo
        where ss.manager_id is not NULL and jo.eid <> _eid
            and ss.sdate <= now()::date and ss.sdate >= (now():: date - 3)
            and jo.room = ss.room and jo.jfloor = ss.sfloor
            and jo.jtime = ss.stime and jo.jdate = ss.sdate
            and exists (select * from Joins as jo2 where jo2.eid = _eid
                and jo2.room = ss.room and jo2.jfloor = ss.sfloor
                and jo2.jtime = ss.stime and jo2.jdate = ss.sdate
            )
        )
    LOOP
    -- updates Close_Contacts table (add affect_date D+1 to D+7)
        _affected_date = now()::date + 1;
        WHILE _affected_date <= now()::date + 7 LOOP
            -- check primary key constraint before insert
            if not exists (select * from Close_Contacts 
                where Close_Contacts.eid = close_contact_eid and Close_Contacts.affect_date = _affected_date) then
                INSERT INTO Close_Contacts(eid, affect_date) VALUES (close_contact_eid, _affected_date);
            end if;
            _affected_date := _affected_date + 1;
        END LOOP;
    -- remove their future bookings and other's join (D+1 to D+7)
        -- remove joins first
        FOR close_contact_session_to_remove IN SELECT * FROM Sessions WHERE Sessions.booker_id=close_contact_eid 
            and Sessions.sdate >= now()::date + 1 and Sessions.sdate <= now()::date + 7
        LOOP
            delete from Joins where Joins.room = close_contact_session_to_remove.room and Joins.jfloor = close_contact_session_to_remove.sfloor 
                                    and Joins.jtime = close_contact_session_to_remove.stime and Joins.jdate = close_contact_session_to_remove.sdate;
        END LOOP;
        -- remove sessions then
        delete from Sessions where Sessions.booker_id=close_contact_eid 
            and Sessions.sdate >= now()::date + 1 and Sessions.sdate <= now()::date + 7;
    -- remove their future joins (D+1 to D+7)
        delete from Joins where Joins.eid = close_contact_eid and Joins.jdate >= now()::date+1 and Joins.jdate <= now()::date+7;
    END LOOP;

    return query 
        select jo.eid as close_contact_eid
        from Sessions as ss, Joins as jo
        where ss.manager_id is not NULL and jo.eid <> _eid
            and ss.sdate <= now()::date and ss.sdate >= (now():: date - 3)
            and jo.room = ss.room and jo.jfloor = ss.sfloor
            and jo.jtime = ss.stime and jo.jdate = ss.sdate
            and exists (select * from Joins as jo2 where jo2.eid = _eid
                and jo2.room = ss.room and jo2.jfloor = ss.sfloor
                and jo2.jtime = ss.stime and jo2.jdate = ss.sdate);
end;
$$LANGUAGE plpgsql;


/* 
 * Admin_1: find all employees that do not comply with the daily health declaration 
 * input: 
 * output:
 */
CREATE OR REPLACE FUNCTION NonCompliance (IN sdate DATE, IN edate DATE)
RETURNS TABLE(EmployeeID INT, NumberOfDays INT) AS $$
BEGIN 
    IF sdate > edate THEN
        raise exception 'Compliance tracing failed. The start date is after end date.';
    END IF;
    
    IF edate > now()::date THEN
        raise exception 'Compliance tracing failed. The end date is in the future.';
    END IF;

    RETURN QUERY
        SELECT e.eid AS EmployeeID, CASE 
            -- the employee resigned between start date and end date.
            WHEN e.resigned_date IS NOT NULL AND e.resigned_date > sdate AND e.resigned_date < edate THEN 
                (((edate - resigned_date) + 1) - cast((SELECT COUNT(*) FROM Health_declarations h WHERE h.eid = e.eid) as int))
            -- the employee do not resign or will resign after end date.
            ELSE 
                (((edate - sdate) + 1) - cast((SELECT COUNT(*) FROM Health_declarations h WHERE h.eid = e.eid) as int))
        END AS NumberOfDays
        FROM Employees e
            -- The employee do not resign or will resign after end date.
        WHERE (SELECT COUNT(*) FROM Health_declarations h WHERE h.eid = e.eid) <> ((edate - sdate)+1) 
            -- For the employee who will resign before end date and after start date, the number of health declarations should equal to the number of dates from start date to resign date
            AND (e.resigned_date IS NULL 
                OR (SELECT COUNT(*) FROM Health_declarations h WHERE h.eid = e.eid) <> ((edate - e.resigned_date)+1) )
            -- The employee resigned before the start date. Then no need to check the compliance of health declaration
            AND (e.resigned_date IS NULL OR e.resigned_date > sdate)
            AND (SELECT COUNT(*) FROM Employees e2 WHERE e2.eid = e.eid AND resigned_date IS NOT NULL AND resigned_date < sdate) = 0 
        ORDER BY NumberOfDays DESC;
END;
$$ LANGUAGE plpgsql;
-- Can try importing the following function(version without consideration of resigned_date) and run the valid test sentence in test.sql to see difference.
-- CREATE OR REPLACE FUNCTION NonCompliance (IN sdate DATE, IN edate DATE)
-- RETURNS TABLE(EmployeeID INT, NumberOfDays INT) AS $$
-- BEGIN 
--     IF sdate > edate THEN
--         raise exception 'Compliance tracing failed. The start date is after end date.';
--     END IF;
    
--     IF edate > now()::date THEN
--         raise exception 'Compliance tracing failed. The end date is in the future.';
--     END IF;

--     RETURN QUERY
--         SELECT e.eid AS EmployeeID, (((edate - sdate) + 1) - cast((SELECT COUNT(*) FROM Health_declarations h WHERE h.eid = e.eid) as int))
--         FROM Employees e
--         WHERE (SELECT COUNT(*) FROM Health_declarations h WHERE h.eid = e.eid) <> ((edate - sdate)+1)
--         ORDER BY (((edate - sdate) + 1) - cast((SELECT COUNT(*) FROM Health_declarations h WHERE h.eid = e.eid) as int)) DESC;
-- END;
-- $$ LANGUAGE plpgsql;


/* 
 * Admin_2: used by employee to find all meeting rooms that are booked by the employee
 * input: sdate, eid
 * output: floor_number, room_number, meeting_date, start_time, start_hour, approved
 */
CREATE OR REPLACE FUNCTION view_booking_report (IN _sdate DATE, IN _eid INT) 
RETURNS TABLE(FloorNumber INT, RoomNumber INT, MeetingDate Date, StartHour TIME, Is_Approved BOOLEAN) AS $$
DECLARE
    current_eid INT;
BEGIN
    SELECT eid INTO current_eid FROM Employees WHERE eid = _eid;
    IF current_eid IS NULL THEN
        raise exception 'View Failed. There is no employee with such id.';
    ELSE
        RETURN QUERY
            SELECT sfloor AS FloorNumber, room AS RoomNumber, sdate AS MeetingDate, stime AS StartHour, CASE
                WHEN s.manager_id IS NULL THEN FALSE
                ELSE TRUE
                END AS Is_Approved
            FROM Sessions s
            WHERE s.booker_id = _eid AND s.sdate > _sdate
            ORDER BY sdate ASC, stime ASC;
    END IF;
END;
$$ LANGUAGE plpgsql;

/* 
 * Admin_3:  used by employee to find all future meetings this employee is going to have that are already approved.
 * input: sdate, eid
 * output: floor_number, room_number, meeting_date, start_time, start_hour
 */
CREATE OR REPLACE FUNCTION view_future_meeting (IN _sdate DATE, IN id INT) 
RETURNS TABLE(FloorNumber INT, RoomNumber INT, MeetingDate Date, StartHour Time) AS $$
DECLARE
    current_eid INT;
BEGIN
    SELECT eid INTO current_eid FROM Employees WHERE eid = id;
    IF current_eid IS NULL THEN
        raise exception 'View Failed. There is no employee with such id.';
    ELSE
        RETURN QUERY
            SELECT sfloor AS FloorNumber, room AS RoomNumber, sdate AS MeetingDate, stime AS StartHour
            FROM Sessions s
            WHERE s.booker_id = id AND s.sdate >= _sdate AND s.manager_id IS NOT NULL
            ORDER BY sdate ASC, stime ASC;
    END IF;
END;
$$ LANGUAGE plpgsql;


/* 
 * Admin_4:  used by manager to find all meeting rooms that require approval
 * input: 
 * output:
 */
CREATE OR REPLACE FUNCTION view_manager_report (IN start_date DATE, IN _eid INT)
RETURNS TABLE(Floor INT, Room INT, Date DATE, Start_hour TIME, EmpID INT) AS $$
DECLARE
	mng_did INT;
    current_eid INT;
BEGIN
    SELECT eid INTO current_eid FROM Managers WHERE eid = _eid;
    IF current_eid IS NULL THEN
        raise exception 'View Failed. There is no manager with such id.';
    END IF;

    SELECT did INTO mng_did FROM Employees WHERE eid = _eid;

	RETURN QUERY
	   	SELECT sfloor, s.room as room, sdate, stime, booker_id
	    FROM Sessions as s, Meeting_Rooms as m
	    WHERE m.did= mng_did AND s.sdate >= start_date AND s.manager_id is NULL
              and s.room = m.room and s.sfloor = m.mfloor
        ORDER BY sdate ASC, stime ASC;
END;
$$ LANGUAGE plpgsql;
