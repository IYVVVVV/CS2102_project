# CS2102_project
uncaptured constraints: 12 16 18 19 21 23 24 25 27 28 31 34

# data.sql contents:
## Department: 
did: 1 - 10

## Employee: 
eid: 1 - 30

Junior: 1 - 10

Booker: 11 - 30

Seinor: 11 - 20

Manager: 21 - 30, correspond to department 1 -10

* first three person in J, S, M is resigned (1-3, 11-13, 21-23)
* all resignation happened 5 days ago to 3 days ago (10.31, 11.1, 11.2)

## Contacts: 
each of employee has 1-3 contact numbers, 8 digits

## Health: 
we record the recent 1 week declaration (10.29-11.5)

resigned employee declare everyday before they resign (resiged_date is 10.31 or 11.1 or 11.2)

current employee with eid ending with 4 fail to declare on 11.3 (2 days ago)

current employee with eid ending with 5 gets fever on 11.4 with temperature > 37.5 (1 day ago)

## Meeting_Rooms:
room: 1 - 10

floor: 1 - 10

* all paired with correspond department 1 - 10
* i.e. each department has 1 meeting room, did=room=floor

## Updates:
manager 1 - 10 update for room 1 - 10, each twice

1st update: cap = 1 or 2

2nd update: new_cap = cap * 2, 1 day later

* all date will be earlier than 7 days ago to prevent resignation

## Sessions & Joins:
we create 2 meetings for department 9, 10 on 1 month later by employee 19, 20

meeting_1: booker-19, room-9, floor-9, date-1 month later, time-12:00-17:00, manager-29, join-19, 9

meeting_2: booker-20, room-10, floor-10, date-1 month later, time-13:00-18:00, manager-NULL, join-20, 4, 5, 6