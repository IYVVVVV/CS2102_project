--remove_employee
--invalid: employee that is booker of some approved meetings
select "remove_employee"(19, '2021-11-02');
--invalid: employee that joins of some approved meetings
select "remove_employee"(9, '2021-11-02');
--valid: employee who is a booker, remove booked session all related joins
select "remove_employee"(20, '2021-11-02');
--valid: rollback approved meetings
select "remove_employee"(29, '2021-11-02');

--add_department
--valid
select "add_department"(11, 'depart_a');
--invalid
select "add_department"(1, 'depart_a');

--view_manager_report
select * from "view_manager_report"('2020-01-01', 30); -- have records
select * from "view_manager_report"('2020-01-01', 29); --no record

--view_future_report
select * from "view_future_meeting"('2020-01-01', 19); -- have records
select * from "view_future_meeting"('2020-01-01', 4); -- no record since no approve
select * from "view_future_meeting"('2020-01-01', 2); -- no record since no meeting