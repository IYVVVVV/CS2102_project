--is_resigned
select "is_resigned"(1); --true
select "is_resigned"(4); --false

--B1:add_department
select "add_department"(11, 'depart_a'); --valid
select "add_department"(1, 'depart_a'); --invalid, exists

--B2:remove_department
select "remove_department"(11); --valid
select "remove_department"(1); --invalid, exists employee and meeting room

--B5: add_employee
select "add_employee"('aaa', '{"12345678", "12345679"}', 'junior', 10) --valid
select "add_employee"('aaa', '{"12345678", "12345679"}', 'senior', 10) --valid, add to both senior and booker

--B6: remove_employee
select "remove_employee"(19, '2021-11-02'); --invalid: employee that is booker of some approved meetings
select "remove_employee"(9, '2021-11-02'); --invalid: employee that joins of some approved meetings
select "remove_employee"(20, '2021-11-02'); --valid: employee who is a booker, remove booked session all related joins
select "remove_employee"(29, '2021-11-02'); --valid: rollback approved meetings

--C4: join_meeting
call JoinMeeting(10, 10, '2021-12-05', '13:00', '14:30', 20); --invalid: the start hour and end hour must be full hour
call JoinMeeting(10, 10, '2021-12-05', '13:00', '11:00', 9); --invalid: the start time is after end time
call JoinMeeting(9, 9, '2021-12-05', '13:00', '14:00', 40); --invalid: no employee with such id
call JoinMeeting(9, 9, '2021-12-05', '13:00', '14:00', 9); --invalid: the session has been approved
call JoinMeeting(10, 10, '2021-12-05', '13:00', '14:00', 3); --invalid: the employee has resigned
call JoinMeeting(10, 10, '2021-11-04', '18:00', '19:00', 5); --invalid: the employee has a fever
call JoinMeeting(10, 10, '2021-11-04', '12:00', '13:00', 9); --invalid: there is no session with given room, floor, date, time
call JoinMeeting(10, 10, '2021-12-05', '13:00', '14:00', 9); --invalid: the employee has joined another session held at the same time
call JoinMeeting(10, 10, '2021-12-05', '13:00', '14:00', 10); --invalid: the number of participants has reached the capacity limit of the room
call JoinMeeting(10, 10, '2021-12-05', '13:00', '14:00', 20); --(after call LeaveMeeting of this) valid
call JoinMeeting(10, 10, '2021-12-05', '13:00', '14:00', 20); --(repeate once more) invalid: the employee has already joined

--C5: leave_meeting
call LeaveMeeting(10, 10, '2021-12-05', '13:00', '14:30', 20); --invalid: the start hour and end hour must be full hour
call LeaveMeeting(10, 10, '2021-12-05', '13:00', '11:00', 9); --invalid: the start time is after end time
call LeaveMeeting(9, 9, '2021-12-05', '12:00', '13:00', 30); --invalid: no employee with such id
call LeaveMeeting(9, 9, '2021-12-05', '12:00', '13:00', 19); --invalid: the meeting has been approved
call LeaveMeeting(10, 10, '2021-11-04', '12:00', '13:00', 9); --invalid: there is no session with given room, floor, date, time
call LeaveMeeting(10, 10, '2021-12-05', '13:00', '14:00', 20); --valid: the employee with id 20 left the session
call LeaveMeeting(10, 10, '2021-12-05', '13:00', '14:00', 20); --(repeate once more) invalid: the employee has already left

--C6: approve_meeting
select "approve_meeting"( 9, 9, '2021-12-07', '12:00', '17:00', 19, 29,TRUE); -- valid
select "approve_meeting"( 9, 9, '2021-12-07', '12:00', '17:00', 19, 29,TRUE); -- invalid, The room 9 in floor 9 is already booked at time 12:00:00 and date 2021-12-07
select "approve_meeting"( 10, 10, '2021-12-07', '12:00', '17:00', 20, 22,TRUE); -- invalid,  Manager 22 is resigned!
select "approve_meeting"( 9, 9, '2021-12-12', '9:00', '17:00', 18, 29,TRUE); -- valid


--H1: declare_health
select "declare_health"(1, '2021-11-05', '36');--invalid, resign
select "declare_health"(4, '2021-11-05', '38');--invalid, exist
select "declare_health"(4, '2021-11-11', '38');--invalid, future
select "declare_health"(4, '2020-11-05', '38');--valid, fever

--H2: contact tracing
select "declare_health"(19, now()::date, 40);
select "declare_health"(15, now()::date, 36);
select * from "contact_tracing"(15);
select * from "contact_tracing"(19);

--A1
select NonCompliance('2021-10-10','2021-10-01'); --invalid: the start date is after end date
select NonCompliance('2021-10-10','2021-12-10'); --invalid: the end date is in the future
select NonCompliance('2021-10-10','2021-11-07'); --valid

--A2: view_booking_report
select * from "view_booking_report"('2020-01-01', 19); -- have records
select * from "view_booking_report"('2020-01-01', 9); -- no records

--A3: view_future_report
select * from "view_future_meeting"('2020-01-01', 19); -- have records
select * from "view_future_meeting"('2020-01-01', 4); -- no record since no approve
select * from "view_future_meeting"('2020-01-01', 2); -- no record since no meeting

--A4:view_manager_report
select * from "view_manager_report"('2020-01-01', 30); -- have records
select * from "view_manager_report"('2020-01-01', 29); --no record
