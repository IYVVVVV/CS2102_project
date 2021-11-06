CREATE OR REPLACE FUNCTION is_resigned(IN _eid INT)
RETURNS BOOLEAN AS $$
DECLARE
    rdate DATE;
BEGIN 
    SELECT resigned_date INTO rdate FROM Employees WHERE Employees.eid=_eid;
    RETURN rdate is NOT NULL AND rdate<=now()::date;
END;
$$ LANGUAGE plpgsql;


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

	FOR emps IN SELECT * FROM Employees WHERE Employees.did=_did LOOP
		IF is_resigned(emps.eid) THEN
			RAISE 'Remove failed. Some employees in this department % is not removed yet', _did;
		END IF;
	END LOOP;
    IF (SELECT count(*) FROM Meeting_Rooms WHERE Meeting_Rooms.did=_did ) <> 0 THEN
        RAISE 'Remove failed. Delete all meeting rooms inside department % before deleting the department!', _did;
    END IF;

    DELETE FROM Departments WHERE Departments.did = _did;
    return 0;
end;
$$ LANGUAGE plpgsql;

/* 
 * Basic_3: add a new meeting room
 * input: 
 * output:
 */
CREATE OR REPLACE FUNCTION add_room(_room_num INTEGER, _room_floor INTEGER, _room_name varchar(100), _room_capacity INTEGER, _did INTEGER, _manager_id INTEGER, _update_date DATE)
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
	INSERT INTO Updates(manager_id, room, ufloor, udate, new_cap) VALUES (_manager_id, _room_num, _room_floor, _update_date, _room_capacity);
	RETURN 0;
END	
$$ LANGUAGE plpgsql;


/* 
 * Basic_4: change the capacity of the room
 * input: 
 * output:
 */
CREATE OR REPLACE FUNCTION change_capacity(_manager_id INTEGER, _room_num INTEGER, _room_floor INTEGER, _new_capacity INTEGER, _update_date DATE)
RETURNS INT AS $$
DECLARE
	manager_did INT;
	room_did INT;
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
	-- update the Updates table
	UPDATE Updates
	SET manager_id = _manager_id, udate = _update_date, new_cap = _new_capacity
	WHERE room = _room_num AND ufloor = _room_floor;
	RETURN 0;
	-- unbook any booked sessions with more participants than capacity after _update_date
	
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
        
    select count(*) into num_records
    from Joins as j, Sessions as s
    where j.room = s.room and j.jfloor = s.sfloor and j.jtime = s.stime and j.jdate = s.sdate
        and j.eid = _eid and s.manager_id is not null
        and j.jdate > _resigned_date;
    if num_records <> 0 then
        raise exception 'Remove failed. The employee joins some approved meetings later then the given date.';
    end if;
        
    update Employees set resigned_date = _resigned_date where eid = _eid;
    
    -- remove his booking session ans all joins
    -- remove joins first
    FOR session_to_remove IN SELECT * FROM Sessions WHERE Sessions.booker_id=_eid LOOP
        delete from Joins as j where j.room = session_to_remove.room and j.jfloor = session_to_remove.sfloor 
                                and j.jtime = session_to_remove.stime and j.jdate = session_to_remove.sdate;
    END LOOP;
    -- remove sessions then
    delete from Sessions where Sessions.booker_id = _eid;

    --rollback approval for meetings if eid is the manager who approved the meeting
    update Sessions set manager_id = NULL where manager_id = _eid;

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
 * Core_2: book a given room
 * input: 
 * output:
 */
CREATE OR REPLACE FUNCTION IsResigned(IN _eid INTEGER)
RETURNS BOOLEAN AS $$
DECLARE
    rdate DATE;
BEGIN 
    SELECT resigned_date INTO rdate FROM Employees WHERE Employees.eid = _eid;
	RETURN rdate IS NOT NULL AND rdate<=now()::date;
END;
$$ LANGUAGE plpgsql;
 
CREATE OR REPLACE FUNCTION book_room (_room_num INTEGER, _room_floor INTEGER, _start_hour TIME, _end_hour TIME, _session_date DATE, _booker_id INTEGER)
RETURNS INT AS $$
DECLARE
	current_hour TIME := _start_hour;
	each_hour TIME[];
	var_hour TIME;
	start_hour_ok INTEGER := 0;
	end_hour_ok INTEGER := 0;
	has_been_booked INTEGER := 0;
BEGIN
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
	IF IsResigned(_booker_id) THEN 
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
	
	WHILE current_hour < _end_hour LOOP
		INSERT INTO Sessions VALUES (_room_num, _room_floor, current_hour, _session_date, _booker_id, NULL);
		current_hour := current_hour + '1 hour';
	END LOOP;
	RETURN 0;
END;
$$ LANGUAGE plpgsql;

/* 
 * Core_3: remove booking of a given room
 * input: 
 * output:
 */
CREATE OR REPLACE FUNCTION unbook_room (_room_num INTEGER, _room_floor INTEGER, _start_hour TIME, _end_hour TIME, _session_date DATE, _unbooker_id INTEGER)
RETURNS INT AS $$
DECLARE
	current_hour TIME := _start_hour;
	unbooker_ok INTEGER := 1;
	start_hour_ok INTEGER := 0;
	end_hour_ok INTEGER := 0;
	each_hour TIME[];
	var_hour TIME;
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
	-- check unbooker_id is book_id
	WHILE current_hour < _end_hour LOOP
		SELECT booker_id FROM Sessions s WHERE s.room = _room_num AND s.sfloor = _room_floor AND s.sdate = _session_date;
		IF _unbooker_id <> booker_id THEN 
			unbooker_ok := 0;
		END IF;
		current_hour := current_hour + '1 hour';
	END LOOP;
	IF unbooker_ok = 1 THEN
		RAISE EXCEPTION 'The unbooker and booker must be the same person';
	END IF;
	-- check unbook everything
	IF EXISTS (SELECT 1 FROM Sessions s WHERE s.room = _room_num AND s.sfloor = _room_floor AND s.sdate = _session_date AND s.stime = _start_hour - '1 hour' AND s.booker_id = _unbooker_id) THEN
		RAISE EXCEPTION 'The unbook must be performed on the whole meeting!';
	END IF;
	IF EXISTS (SELECT 1 FROM Sessions s WHERE s.room = _room_num AND s.sfloor = _room_floor AND s.sdate = _session_date AND s.stime = _start_hour + '1 hour' AND s.booker_id = _unbooker_id) THEN
		RAISE EXCEPTION 'The unbook must be performed on the whole meeting!';
	END IF;
	-- perform deletion
	DELETE FROM Sessions s
	WHERE s.room = _room_num
	AND s.sfloor = _room_floor
	AND s.sdate = _session_date
	AND s.stime >= _start_hour
	AND s.stime < _end_hour;
	RETURN 0;
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
    current_eid INT;
    meeting_room INT;
    resigned DATE;
    fever_id INT;
    joined_id INT; 
BEGIN
    SELECT eid INTO current_eid FROM Employees WHERE eid = id;
    IF current_eid IS NULL THEN
        raise exception 'Join Failed. There is no employee with such id.';
    ELSE
        SELECT room INTO meeting_room FROM Sessions WHERE room = room_number AND sfloor = floor_number AND stime = temp AND sdate = meeting_date AND manager_id IS NULL;
        IF meeting_room IS NULL THEN
            raise exception 'Join failed. The meeting has been approved already.';
        END IF;

        SELECT resigned_date INTO resigned FROM Employees WHERE eid = id;
        IF resigned IS NOT NULL AND meeting_date > resigned THEN
            raise exception 'Join failed. The employee has resigned.';
        END IF;

        SELECT h.eid INTO fever_id FROM Health_declarations h WHERE h.eid = id and fever = true;
        IF fever_id IS NOT NULL THEN
            raise exception 'Join failed. The employee has a fever.';
        END IF;
            
        SELECT eid INTO joined_id FROM Joins j WHERE j.eid = id AND room = room_number AND jfloor = floor_number AND jtime = temp AND jdate = meeting_date;
        IF joined_id IS NOT NULL THEN
            raise exception 'Join failed. The employee has already joined the meeting';
        END IF;

        WHILE temp > end_hour LOOP
            INSERT INTO Joins VALUES (id, room_number, floor_number, temp, meeting_date);
            temp := temp + '1 hour';
        END LOOP;
    END IF;
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
    current_eid INT;
    meeting_room INT;
    joined_id INT; 
BEGIN
    SELECT eid INTO current_eid FROM Employees WHERE eid = id;
    IF current_eid IS NULL THEN
        raise exception 'Leave Failed. There is no employee with such id.';
    ELSE
        SELECT room INTO meeting_room FROM Sessions WHERE room = room_number AND sfloor = floor_number AND stime = temp AND sdate = meeting_date AND manager_id IS NULL;
        IF meeting_room IS NULL THEN
            raise exception 'Leave failed. The meeting has been approved already.';
        END IF;

        SELECT eid INTO joined_id FROM Joins j WHERE j.eid = id AND room = room_number AND jfloor = floor_number AND jtime = temp AND jdate = meeting_date;
        IF joined_id IS NULL THEN
            raise exception 'Leave failed. The employee has already leaved the meeting or did not join the meeting';
        END IF;

        WHILE temp > end_hour LOOP
            DELETE FROM Joins WHERE eid = id AND room = room_number AND jfloor = floor_number AND jtime = temp AND jdate = meeting_date;
            temp := temp + '1 hour';
        END LOOP;
    END IF;
END;
$$ LANGUAGE plpgsql;


/* 
 * Core_6: approve a booking
 * input: 
 * output:
 */
CREATE OR REPLACE function approve_meeting (IN floor_num INT, room_num INT, IN date DATE, IN start_hour TIME, IN end_hour TIME, IN booker_eid INT, IN approve_eid INT) 
RETURNS INT AS $$
DECLARE 
	mng_did INT; expect_did INT; rdate DATE;
BEGIN
	SELECT did INTO mng_did FROM Managers WHERE eid=approve_eid;
	IF mng_did IS NULL THEN
		RAISE 'The given eid % is not a manager!', approve_eid;
	END IF;
	
	IF is_resigned(approve_eid) THEN 
        RAISE 'Manager % is resigned!', approve_eid;
    END IF;
    
    SELECT did INTO expect_did FROM Meeting_Rooms WHERE mfloor=floor_num and Room=room_num;
	IF expect_did IS NULL THEN
		RAISE 'The given room % in % floor does not exist!', room_num, floor_num;
	END IF;

    IF mng_did=expect_eid THEN
        INSERT INTO Sessions VALUES(room_num, floor_num, start_hour, booker_eid, approve_eid);
	ELSE 
		RAISE 'The given manager % is not in charge of this room', approve_eid;
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
 * output:
 */
--create or replace function contact_tracing


/* 
 * Admin_1: find all employees that do not comply with the daily health declaration 
 * input: 
 * output:
 */
--create or replace function non_compliance


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
