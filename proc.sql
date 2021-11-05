/* 
 * Basic_1: add a new department
 * input: 
 * output:
 */
CREATE OR REPLACE PROCEDURE add_department (IN did INT, IN ame VARCHAR(100))
AS $$
	INSERT INTO Departments VALUES (did,ame);
$$ LANGUAGE sql;


/* 
 * Basic_2: remove a department
 * input: 
 * output:
 */
CREATE OR REPLACE PROCEDURE remove_department (IN did INT)
AS $$
	FOR emps IN SELECT eid FROM Employees WHERE Employees.did=did LOOP
		IF SELECT IsResigned(emps) THEN
			RAISE 'Some employees in this department % is not removed yet', did;
		END IF；
	END LOOP

DELETE FROM Departments WHERE Departments.did=did;
$$ LANGUAGE sql;

/* 
 * Basic_3: add a new meeting room
 * input: 
 * output:
 */
CREATE OR REPLACE FUNCTION add_room(_room_num INTEGER, _room_floor INTEGER, _room_name varchar(100), _room_capacity INTEGER, _did INTEGER, _manager_id INTEGER, _update_date DATE);
RETURNS INT AS $$
BEGIN
	-- some check
	
	
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
BEGIN
	-- some check
	
	-- update the Updates table
	UPDATE Updates
	SET manager_id = _manager_id, udate = _update_date, new_cap = _new_capacity
	WHERE room = _room_num AND ufloor = _room_floor;
	RETURN 0;
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
        raise exception 'Invalid employee job kind, should be junior, senior or manager.';
    end if;
    -- check contact numbers
    if _contact_numbers is NULL then
        raise exception 'At least one contact number is required.';
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
begin
    num_records := 0;
    select eid from Employees where eid = _eid into current_eid;
    if current_eid is null then
        raise exception 'Remove failed. No employee with the given eid.';
    else
        -- reject the remove if the employee has already be removed
        select resigned_date into old_resigned_date from Employees where eid = _eid;
        if old_resigned_date is not null then
            raise exception 'Remove failed. The employee has been removed before.';
        end if;
        
        -- reject the remove if the employee joins an approved session later then the given date
        select count(*) into num_records
        from Joins as j, Sessions as s
        where j.room = s.room and j.jfloor = s.sfloor and j.jtime = s.stime and j.jdate = s.sdate
            and j.eid = _eid and s.manager_id is not null
            and j.jdate > _resigned_date;
        if num_records <> 0 then
            raise exception 'Remove failed. The employee joins some approved meetings later then the given date.';
        end if;
        
        update Employees set resigned_date = _resigned_date where eid = _eid;
            return 0;
    end if;
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
END
$$ LANGUAGE plpgsql


/* 
 * Core_2: book a given room
 * input: 
 * output:
 */
CREATE OR REPLACE FUNCTION book_room (_room_num INTEGER, _room_floor INTEGER, _start_hour TIME, _end_hour TIME, _session_date DATE, _booker_id INTEGER, _manager_id INTEGER)
RETURNS INT AS $$
DECLARE
	current_hour TIME := _start_hour;
BEGIN
	WHILE current_hour < _end_hour LOOP
		INSERT INTO Sessions VALUES (_room_num, _room_floor, current_hour, _session_date, _booker_id, _manager_id);
		current_hour := current_hour + '1 hour';
	END LOOP;
	RETURN 0;
END
$$ LANGUAGE plpgsql

/* 
 * Core_3: remove booking of a given room
 * input: 
 * output:
 */
CREATE OR REPLACE FUNCTION unbook_room (_room_num INTEGER, _room_floor INTEGER, _start_hour TIME, _end_hour TIME, _session_date DATE, _booker_id INTEGER)
RETURNS INT AS $$
BEGIN
	DELETE FROM Sessions s
	WHERE s.room = _room_num
	AND s.sfloor = _room_floor
	AND s.sdate = _session_date
	AND s.stime >= _start_hour
	AND s.stime < _end_hour;
	RETURN 0;
END
$$ LANGUAGE plpgsql

/* 
 * Core_4: join a booked meeting room
 * input: floor_number, room_number, meeting_date, start_hour, end_hour, eid
 * output: null cause a procedure
 */
CREATE OR REPLACE PROCEDURE JoinMeeting (IN floor_number INT, IN room_number INT, IN meeting_date Date, IN start_hour INT, IN end_hour INT, IN id INT) AS $$
DECLARE 
    temp INT := start_hour;
    meeting_room INT;
    resigned INT;
    fever_id INT;
    joined_id INT; 
BEGIN
    WHILE temp > end_hour LOOP
        SELECT room INTO meeting_room FROM Sessions WHERE room = room_number AND sfloor = floor_number AND stime = temp AND sdate = meeting_date AND manager_id IS NULL;
        IF meeting_room IS NULL THEN
            raise exception 'Join failed. The meeting has been approved already.';
        ELSE
            SELECT resign_date INTO resigned FROM Employees WHERE eid = id;
            IF resigned IS NOT NULL AND meeting_date > resigned THEN
                raise exception 'Join failed. The employee has resigned.';
            END IF;

            SELECT h.eid INTO fever_id FROM Health_declarations h WHERE h.eid = id and fever = true;
            IF fever_id IS NOT NULL THEN
                raise exception 'Join failed. The employee has a fever.';
            END IF;
            
            SELECT eid INTO joined_id FROM Joins j WHERE j.eid = id AND room = room_number AND jfloor = floor_number AND jtime = cast(convert（varchar(8),temp）as time) AND jdate = meeting_date;
            IF joined_id IS NOT NULL THEN
                raise exception 'Join failed. The employee has already joined the meeting';
            END IF;

            INSERT INTO Joins VALUES (id, room_number, floor_number, cast(convert（varchar(8),temp）as time), meeting_date);
        END IF;
        temp := temp + 10000;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
/* 
 * Core_5: leave a booked meeting room
 * input: floor_number, room_number, meeting_date, start_hour, end_hour, eid
 * output: null cause a procedure
 */
CREATE OR REPLACE PROCEDURE LeaveMeeting (IN floor_number INT, IN room_number INT, IN meeting_date Date, IN start_hour INT, IN end_hour INT, IN id INT) AS $$
DECLARE 
    temp INT := start_hour;
    meeting_room INT;
    joined_id INT; 
BEGIN
    WHILE temp > end_hour LOOP
        SELECT room INTO meeting_room FROM Sessions WHERE room = room_number AND sfloor = floor_number AND stime = temp AND sdate = meeting_date AND manager_id IS NULL;
        IF meeting_room IS NULL THEN
            raise exception 'Leave failed. The meeting has been approved already.';
        ELSE
            SELECT eid INTO joined_id FROM Joins j WHERE j.eid = id AND room = room_number AND jfloor = floor_number AND jtime = cast(convert（varchar(8),temp）as time) AND jdate = meeting_date;
            IF joined_id IS NULL THEN
                raise exception 'Leave failed. The employee did not joind the session or has left.'
            END IF;

            DELETE FROM Joins WHERE eid = id AND room = room_number AND jfloor = floor_number AND jtime = cast(convert（varchar(8),temp）as time) AND jdate = meeting_date;
        END IF;
        temp := temp + 10000;
    END LOOP;
END;
$$ LANGUAGE plpgsql;


/* 
 * Core_6: approve a booking
 * input: 
 * output:
 */
create or replace function approve_meeting
CREATE OR REPLACE FUNCTION IsResigned(IN eid INT)
RETURNS BOOLEAN AS $$
DECLARE
    rdate DATE;
BEGIN 
    SELECT resign_date INTO rdate FROM Employees WHERE Employees.eid=eid;
	RETURN rdate NOT NULL AND rdate<=now()::date;
END
$$ LANGUAGE plpgsql;


CREATE OR REPLACE PROCEDURE approve_meeting (IN floor_num INT, room_num INT, IN date DATE, IN start_hour TIME, IN end_hour TIME, IN booker_eid INT, IN approve_eid INT) 
AS $$
DECLARE 
	mng_did INT; expect_did INT; rdate DATE;
BEGIN
	SELECT did INTO mng_did FROM Managers WHERE eid=approve_eid;
	IF mng_did IS NULL THEN
		RAISE 'The given eid % is not a manager!', approve_eid
		USING HINT = 'Please check the manager eid';
	END IF;
	
	IF SELECT IsResigned(approve_eid) THEN 
        RAISE 'Manager % is resigned!', approve_eid
		USING HINT = 'Please check the manager eid';
    END　IF;
    
    SELECT did INTO expect_did FROM Meeting_Rooms WHERE mfloor=floor_num, Room=room_num;
	IF expect_did IS NULL THEN
		RAISE 'The given room % in % floor does not exist!', room_num, floor_num;
		USING HINT = 'Please Check the room and floor';
	END IF;

    IF mng_did=expect_eid THEN
        INSERT INTO Sessions VALUES(room_num, floor_num, start_hour, booker_eid, approve_eid)
	ELSE 
		RAISE 'The given manager % is not in charge of this room', approve_eid
		USING HINT = 'Please check the manager and the room';
    END IF；
END;
$$ LANGUAGE plpgsql;

/* 
 * Health_1: used for daily declaration of temperature
 * input: 
 * output:
 */
create or replace function declare_health


/* 
 * Health_2: used for contact tracing
 * input: 
 * output:
 */
create or replace function contact_tracing


/* 
 * Admin_1: find all employees that do not comply with the daily health declaration 
 * input: 
 * output:
 */
create or replace function non_compliance


/* 
 * Admin_2: used by employee to find all meeting rooms that are booked by the employee
 * input: sdate, eid
 * output: floor_number, room_number, meeting_date, start_time, start_hour, approved
 */
CREATE OR REPLACE FUNCTION ViewBookingReport (IN sdate DATE, IN eid INT) 
RETURNS TABLE(FloorNumber INT, RoomNumber INT, MeetingDate Date, StartTime TIME, StartHour INT, Approved VARCHAR(20)) AS $$
    SELECT sfloor AS FloorNumber, room AS RoomNumber, sdate AS MeetingDate, stime AS StartTime, convert(int, cast(stime as varchar(8))) AS StartHour, CASE
        WHEN s.manager_id IS NULL THEN 'No'
        ELSE 'Yes'
    END AS Approved
    FROM Sessions s
    WHERE s.booker_id = eid AND s.sdate > sdate
    ORDER BY sdate ASC, stime ASC;
$$ LANGUAGE sql;


/* 
 * Admin_3:  used by employee to find all future meetings this employee is going to have that are already approved.
 * input: sdate, eid
 * output: floor_number, room_number, meeting_date, start_time, start_hour
 */
CREATE OR REPLACE FUNCTION ViewFutureMeeting (IN sdate DATE, IN eid INT) 
RETURNS TABLE(FloorNumber INT, RoomNumber INT, MeetingDate Date, StartTime TIME, StartHour INT) AS $$
    SELECT sfloor AS FloorNumber, room AS RoomNumber, sdate AS MeetingDate, stime AS StartTime, convert(int, cast(stime as varchar(8))) AS StartHour
    FROM Sessions s
    WHERE s.booker_id = eid AND s.sdate > sdate AND s.manager_id IS NOT NULL
    ORDER BY sdate ASC, stime ASC;
$$ LANGUAGE sql;




/* 
 * Admin_4:  used by manager to find all meeting rooms that require approval
 * input: 
 * output:
 */
CREATE OR REPLACE FUNCTION view_manager_report (IN start_date DATE, IN eid INT)
RETURNS TABLE(Floor INT, Room INT, Date DATE, Start_hour TIME, EmpID INT) AS $$
DECLARE
		mng_did INT;
BEGIN
		IF eid IN (SELECT eid FORM Managers) THEN
		    SELECT did INTO mng_did FROM Managers WHERE Managers.eid=eid;
			 RETURNS QUERY
			   	SELECT sfloor, room, sdate, stime, booker_id
			    FROM Sessions NATURAL JOIN Meeting_Rooms
			    WHERE Meeting_Rooms.did= mng_did AND sdate >= start_date AND manager_id=eid
                ORDERED BY sdate, stime;
		ELSE
			RETURN;
		END IF
END;
$$ LANGUAGE plpgsql;
