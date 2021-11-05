import argparse
from random import randint, choice, random, uniform
import datetime


# Total 12 tables: 
# Employees, Juniors, Bookers, Seniors, Managers, 
# Contacts, Health_declarations,
# Departments, Meeting_Rooms, Updates, 
# Sessions, Joins

LOWER_CHARS = 'abcdefghijklmnopqrstuvwxyz'
UPPER_CHARS = LOWER_CHARS.upper()
NUMBERS = '0123456789'

# save values for foreign key constraints
employee_ids = []
current_employee_ids = []
resigned_eployee_ids = []
resigned_tuples = [] # (eid, resign_date) pairs
booker_ids = []
manager_ids = []
department_ids = []
meeting_rooms = []  # (room, floor) pairs
sessions = []  # (room, floor, time, date) tuples

def get_random_depart_name():
    first_char = choice(UPPER_CHARS)
    rest_chars = ''.join([choice(LOWER_CHARS) for i in range(choice(range(3, 9)))])
    return 'Department_' + first_char + rest_chars

def get_random_employee_name_part():
    first_char = choice(UPPER_CHARS)
    rest_chars = ''.join([choice(LOWER_CHARS) for i in range(choice(range(1, 6)))])
    return first_char + rest_chars

def get_random_employee_name():
    first_name = get_random_employee_name_part()
    mid_name = get_random_employee_name_part() if random() < 0.5 else ''
    last_name = get_random_employee_name_part()
    name = ' '.join([first_name, mid_name, last_name]) if mid_name != '' else ' '.join([first_name, last_name])
    return name

def get_email(name, eid):
    return ''.join(name.strip().split(' ')).lower() + '_' + str(eid) + '@gmail.com'

def get_random_contact_number():
    return ''.join([choice(NUMBERS) for i in range(8)])

def get_random_prev_date():
    # get a random date in previous 1 year range
    # we assume all resignation happened from 5 days ago to 3 days ago
    currdate = datetime.datetime.now()  # '2021-11-04'
    currdate_str = currdate.strftime('%Y-%m-%d')
    prevdate = currdate - datetime.timedelta(randint(3, 5)) # i.e. 10.30-11.1
    prevdate_str = prevdate.strftime('%Y-%m-%d')  # eg. '2021-10-31'
    return prevdate, prevdate_str

def get_random_normal_temp():
    temp = 37.5
    while temp == 37.5:
        temp = round(uniform(34.0, 37.5), 1)
    return temp

def get_random_fever_temp():
    return round(uniform(37.5, 43.0), 1)

def create_employees(datafile):
    # add data into table Employees, Juniors, Bookers, Seniors, Managers, and also Contacts
    # eid: 1 - 30
    # Juniors: 1 -10
    # Bookers : 11 - 30; Seniors: 11 - 20; Managers: 21 - 30
    # each department has a manager
    # each of employee has 1-3 contact numbers
    # first three person in J, S, M is resigned (1-3, 11-13, 21-23)
    cmd_e = cmd_j = cmd_b = cmd_s = cmd_m = cmd_c = ''

    for eid in range(1, 31):
        employee_ids.append(eid)
        ename = get_random_employee_name()
        email = get_email(ename, eid)
        did = choice(department_ids)
        resigned_date_str = 'NULL'
        if 1 <= eid % 10 <= 3:
            resigned_eployee_ids.append(eid)
            resigned_date, resigned_date_str = get_random_prev_date()
            resigned_date_str = '\'' + resigned_date_str + '\''
            resigned_tuples.append((eid, resigned_date))
        else:
            current_employee_ids.append(eid)

        if 21 <= eid <= 30:
            did = eid % 10
            did = 10 if did == 0 else did
            cmd_e += f'insert into Employees(ename, email, resigned_date, did) '\
                    + f'values (\'{ename}\', \'{email}\', {resigned_date_str}, {did});\n'
        else:
            cmd_e += f'insert into Employees(ename, email, resigned_date, did) ' \
                     + f'values (\'{ename}\', \'{email}\', {resigned_date_str}, {did});\n'

        if 1 <= eid <= 10:
            cmd_j += f'insert into Juniors(eid) values ({eid});\n'
        else:
            cmd_b += f'insert into Bookers(eid) values ({eid});\n'
            booker_ids.append(eid)
            if 11 <= eid <= 20:
                cmd_s += f'insert into Seniors(eid) values ({eid});\n'
            else:
                cmd_m += f'insert into Managers(eid) values ({eid});\n'
                manager_ids.append(eid)

        for num_contacts in range(choice(range(0,4))):
            contact = get_random_contact_number()
            cmd_c += f'insert into Contacts(eid, contact) values ({eid}, \'{contact}\');\n'

    datafile.write('--Employees\n')
    datafile.write(cmd_e)
    datafile.write('\n')
    datafile.write('--Juniors\n')
    datafile.write(cmd_j)
    datafile.write('\n')
    datafile.write('--Bookers\n')
    datafile.write(cmd_b)
    datafile.write('\n')
    datafile.write('--Seniors\n')
    datafile.write(cmd_s)
    datafile.write('\n')
    datafile.write('--Managers\n')
    datafile.write(cmd_m)
    datafile.write('\n')
    datafile.write('--Contacts\n')
    datafile.write(cmd_c)
    datafile.write('\n')

def create_health_declarations(datafile):
    # add data into Health_declarations
    # we record the recent 1 week declaration (10.28-11.4)

    # since all resignation happened 5 days ago to 3 days ago (10.30, 10.31, 11.1),
    # any record in 11.2-11.4 should not include them, but 10.28-10.29 must have them if they declare

    # we design the data such that resigned employee declare daily before they resign
    # current employee with eid ending with 4 fail to declare on 11.2 (2 days ago)
    # current employee with eid ending with 5 gets fever on 11.3 with temperature > 37.5 (1 day ago)
    cmd = ''
    for eid in current_employee_ids:
        for d in range(8):
            hdate = (datetime.datetime.now() - datetime.timedelta(d)).strftime('%Y-%m-%d')
            htemp = get_random_normal_temp()
            fever = 'FALSE'
            # current employee with eid ending with 4 fail to declare on 11.2 (2 days ago)
            if eid % 4 == 0 and d == 2:
                continue
            # current employee with eid ending with 5 gets fever on 11.3 with temperature > 37.5 (1 day ago)
            if eid % 5 == 0 and d == 1:
                htemp = get_random_fever_temp()
                fever = 'TRUE'
            cmd += f'insert into Health_declarations(eid, hdate, htemp, fever) '\
                + f'values ({eid}, \'{hdate}\', \'{htemp}\', {fever});\n'
    # print(resigned_tuples)
    for eid, resigned_date in resigned_tuples:
        min_d = (datetime.datetime.now() - resigned_date).days
        for d in range(min_d, 8):
            hdate = (datetime.datetime.now() - datetime.timedelta(d)).strftime('%Y-%m-%d')
            htemp = get_random_normal_temp()
            fever = 'FALSE'
            cmd += f'insert into Health_declarations(eid, hdate, htemp, fever) ' \
                   + f'values ({eid}, \'{hdate}\', \'{htemp}\', {fever});\n'

    datafile.write(cmd)
    datafile.write('\n')
        
def create_departments(datafile):
    datafile.write('--Departments\n')
    for did in range(1, 11):
        department_ids.append(did)
        dname = get_random_depart_name()
        cmd  = f'insert into Departments(did, dname) values ({did}, \'{dname}\');\n'
        datafile.write(cmd)
    datafile.write('\n')


def get_random_room_name():
    first_char = choice(UPPER_CHARS)
    rest_chars = ''.join([choice(LOWER_CHARS) for i in range(choice(range(3, 9)))])
    return 'Room_' + first_char + rest_chars

def create_meeting_rooms(datafile):
    # each department has 1 meeting room, did=room=floor
    datafile.write('--Meeting_Rooms\n')
    for did in range(1, 11):
        room = mfloor = did
        meeting_rooms.append((room, mfloor))
        rname = get_random_room_name()
        cmd = f'insert into Meeting_Rooms(room, mfloor, rname, did) values ({room}, {mfloor}, \'{rname}\', {did});\n'
        datafile.write(cmd)
    datafile.write('\n')

def get_random_room_cap_date(did):
    # each room allows 1 - 2 people
    cap = 2 if did % 2 == 0 else 1
    currdate = datetime.datetime.now()  # '2021-11-04'
    prevdate = currdate - datetime.timedelta(randint(7, 14))
    prevdate_str = prevdate.strftime('%Y-%m-%d')  # eg. '2021-10-31'
    return cap, prevdate, prevdate_str

def create_updates(datafile):
    # every manager has update twice for the room from the same department
    # cap1 = 1/2; cap2 = 2 * cap1
    # all date will be earlier than 7 days ago to prevent resignation
    datafile.write('--Updates\n')
    for manager_id in manager_ids:
        did = manager_id % 10
        did = 10 if did == 0 else did
        room = ufloor = did
        cap_1, predate_1, predate_str_1 = get_random_room_cap_date(did)
        cmd = f'insert into Updates(manager_id, room, ufloor, udate, new_cap) ' \
            + f'values ({manager_id}, {room}, {ufloor}, \'{predate_str_1}\', {cap_1});\n'
        cap_2 = cap_1 * 2
        predate_2 = predate_1 + datetime.timedelta(1)
        predate_str_2 = predate_2.strftime('%Y-%m-%d')
        cmd += f'insert into Updates(manager_id, room, ufloor, udate, new_cap) ' \
              + f'values ({manager_id}, {room}, {ufloor}, \'{predate_str_2}\', {cap_2});\n'
        datafile.write(cmd)
    datafile.write('\n')

def create_sessions(datafile):
    # we create 2 meetings for department 9, 10 on 1 month later by employee 19, 20
    # meeting_1: booker-19, room-9, floor-9, date-1 month later, time-12:00-17:00, manager-29, join-19, 9
    # meeting_2: booker-20, room-10, floor-10, date-1 month later, time-13:00-18:00, manager-NULL, join-20, 4,5,6
    datafile.write('--Sessions\n')
    currdate = datetime.datetime.now()
    prevdate = currdate + datetime.timedelta(30)
    prevdate = prevdate.strftime('%Y-%m-%d')
    cmd = ''
    for i in range(12, 18):
        cmd += f'insert into Sessions(room, sfloor, stime, sdate, booker_id, manager_id) ' \
            + f'values (9, 9, \'{i}:00\', \'{prevdate}\', 19, 29);\n'
    for j in range(13, 19):
        cmd += f'insert into Sessions(room, sfloor, stime, sdate, booker_id, manager_id) ' \
               + f'values (10, 10, \'{j}:00\', \'{prevdate}\', 20, NULL);\n'
    datafile.write(cmd)
    datafile.write('\n')

def create_joins(datafile):
    datafile.write('--Joins\n')
    currdate = datetime.datetime.now()
    prevdate = currdate + datetime.timedelta(30)
    prevdate = prevdate.strftime('%Y-%m-%d')
    cmd = ''
    for eid in [19, 9]:
        for i in range(12, 18):
            cmd += f'insert into Joins(eid, room, jfloor, jtime, jdate) ' \
                   + f'values ({eid}, 9, 9, \'{i}:00\', \'{prevdate}\');\n'
    for eid in [20, 4, 5, 6]:
        for i in range(13, 19):
            cmd += f'insert into Joins(eid, room, jfloor, jtime, jdate) ' \
                   + f'values ({eid}, 10, 10, \'{i}:00\', \'{prevdate}\');\n'
    datafile.write(cmd)
    datafile.write('\n')


if __name__ == "__main__":
    # parser = argparse.ArgumentParser()
    # parser.add_argument('--department', action='store_true')
    # args = parser.parse_args()
    with open('new_data.sql', 'w') as datafile:
        # add data into table Employees, Juniors, Bookers, Seniors, Managers, and also Contacts
        create_departments(datafile)
        create_employees(datafile)
        create_health_declarations(datafile)
        create_meeting_rooms(datafile)
        create_updates(datafile)
        create_sessions(datafile)
        create_joins(datafile)