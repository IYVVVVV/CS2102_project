/* 
 * Basic_1: add a new resignment
 * input: 
 * output:
 */
create or replace function add_resignment


/* 
 * Basic_2: remove a resignment
 * input: 
 * output:
 */
create or replace function remove_resignment


/* 
 * Basic_3: add a new meeting room
 * input: 
 * output:
 */
create or replace function add_room


/* 
 * Basic_4: change the capacity of the room
 * input: 
 * output:
 */
create or replace function change_capacity


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
create or replace function search_room


/* 
 * Core_2: book a given room
 * input: 
 * output:
 */
create or replace function book_room


/* 
 * Core_3: remove booking of a given room
 * input: 
 * output:
 */
create or replace function unbook_room


/* 
 * Core_4: join a booked meeting room
 * input: 
 * output:
 */
create or replace function join_meeting


/* 
 * Core_5: leave a booked meeting room
 * input: 
 * output:
 */
create or replace function leave_meeting


/* 
 * Core_6: approve a booking
 * input: 
 * output:
 */
create or replace function approve_meeting


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
 * input: 
 * output:
 */
create or replace function view_booking_report


/* 
 * Admin_3:  used by employee to find all future meetings this employee is going to have that are already approved.
 * input: 
 * output:
 */
create or replace function view_future_meeting


/* 
 * Admin_4:  used by manager to find all meeting rooms that require approval
 * input: 
 * output:
 */
create or replace function view_manager_report