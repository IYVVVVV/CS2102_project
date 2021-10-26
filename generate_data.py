import argparse
from random import randint, choice, random


# Total 12 tables: 
# Employees, Juniors, Bookers, Seniors, Managers, 
# Contacts, Health_declarations,
# Departments, Meeting_Rooms, Updates, 
# Sessions, Joins

LOWER_CHARS = 'abcdefghijklmnopqrstuvwxyz'
UPPER_CHARS = LOWER_CHARS.upper()

# save values for foreign key constraints
employee_ids = []
booker_ids = []
manager_ids = []
department_ids = []
meeting_rooms = []  # (room, floor) pairs
sessions = []  # (room, floor, time, date) tuples

def random_name_part():
    first_char = choice(UPPER_CHARS)
    rest_chars = ''.join([choice(LOWER_CHARS) for i in range(1, 6)])
    return first_char + rest_chars

def random_name():
    first_name = random_name_part()
    mid_name = random_name_part() if random() < 0.5 else ''
    last_name = random_name_part()
    name = ' '.join([first_name, mid_name, last_name]) if mid_name != '' else ' '.join([first_name, last_name])
    return name

def get_email(name):
    return ''.join(name.strip().split(' ')).lower() + '@gmail.com'

def create_employees(datafile):
    pass

def create_health_declarations(datafile):
    pass
        
def create_departments(datafile):
    pass

def create_meeting_rooms(datafile):
    pass

def create_updates(datafile):
    pass

def create_sessions(datafile):
    pass

def create_joins(datafile):
    pass


if __name__ == "__main__":
    # parser = argparse.ArgumentParser()
    # parser.add_argument('--department', action='store_true')
    # args = parser.parse_args()
    with open('new_data.sql', 'w') as datafile:
        # add data into table Employees, Bookers, Seniors, Managers, and also Contacts
        create_employees(datafile)
        create_health_declarations(datafile)
        create_departments(datafile)
        create_meeting_rooms(datafile)
        create_updates(datafile)
        create_sessions(datafile)
        create_joins(datafile)