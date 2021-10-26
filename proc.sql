/* 
 * Basic_1: add a new department
 * input: 
 * output:
 */
 create or replace function add_department


/* 
 * Basic_2: remove a department
 * input: 
 * output:
 */
 create or replace function remove_department


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
 * input: 
 * output:
 */
 create or replace function add_employee


/* 
 * Basic_6: remove a employee
 * input: 
 * output:
 */
 create or replace function remove_employee


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