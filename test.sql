--remove_employee
--invalid: employee that is booker of some approved meetings
select "remove_employee"(19, '2021-11-02');
--invalid: employee that joins of some approved meetings
select "remove_employee"(9, '2021-11-02');
--valid: employee who is a booker, remove booked session all related joins
select "remove_employee"(20, '2021-11-02');
--valid: rollback approved meetings
select "remove_employee"(29, '2021-11-02')