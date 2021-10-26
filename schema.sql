DROP TABLE IF EXISTS
    Employees, Departments, Meeting_Rooms, Updates, Juniors, Bookers, Seniors, Managers, Sessions, Joins

-- health declaration
CREATE TABLE Health_declarations (
    eid INTEGER,
    date DATE,
    temp FLOAT(2) CHECK (temp > 34 AND temp < 43),
    fever BOOLEAN,
    PRIMARY KEY (eid, date),
    FOREIGN KEY (eid) REFERENCES Employees(eid)
)

-- employee (works in)
CREATE TABLE Employees (
	eid INTEGER,
	ename VARCHAR(50),
	email VARCHAR(50) UNIQUE,
	resigned_date DATE,
	did INTEGER NOT NULL,
	PRIMARY KEY(eid),
	FOREIGN KEY(did) REFERENCES Departments(did)
);

-- contacts
CREATE TABLE Contacts (
    eid INTEGER,
    contact TEXT,
    PRIMARY KEY(eid, contact),
    FOREIGN KEY (eid) REFERENCES Employees(eid)
)

-- department
CREATE TABLE Departments (
    did     INTEGER,
    dname   VARCHAR(100),
    PRIMARY KEY (did)
);


-- meeting rooms (locates in)
CREATE TABLE Meeting_Rooms (
    room    INTEGER,
    floor   INTEGER,
    rname   VARCHAR(100),
    did     INTEGER NOT NULL,
    PRIMARY KEY (room, floor),
    FOREIGN KEY (did) REFERENCES Departments(did)
);

-- updates
CREATE TABLE Updates (
    manager_id  INTEGER NOT NULL,
    room        INTEGER,
    floor       INTEGER,
    date        DATE,
    new_cap     INTEGER,
    PRIMARY KEY (manager_id, room, floor, date),
    FOREIGN KEY (manager_id) REFERENCES Manager (eid),
    FOREIGN KEY (room) REFERENCES Meeting_Rooms (room),
    FOREIGN KEY (floor) REFERENCES Meeting_Rooms (floor)
);

-- junior
CREATE TABLE Juniors (
	eid INTEGER,
	FOREIGN KEY(eid) REFERENCES Employees(eid) ON DELETE CASCADE
);

-- booker
CREATE TABLE Bookers (
	eid INTEGER,
	FOREIGN KEY(eid) REFERENCES Employees(eid) ON DELETE CASCADE
);

-- senior
CREATE TABLE Seniors (
	eid INTEGER,
	FOREIGN KEY(eid) REFERENCES Bookers(eid) ON DELETE CASCADE
);

-- manager 
CREATE TABLE Managers (
	eid INTEGER,
	FOREIGN KEY(eid) REFERENCES Bookers(eid) ON DELETE CASCADE
);

-- session (with rname, with books, with manager)
CREATE TABLE Sessions (
    room    INTEGER,
    floor   INTEGER,
    time    TIME,
    date    DATE,
    booker_id INTEGER NOT NULL,
    manager_id INTEGER UNIQUE,
    PRIMARY KEY (room, floor, time, date),
    FOREIGN KEY (room) REFERENCES Meeting_Rooms (room) ON DELETE CASCADE,
    FOREIGN KEY (floor) REFERENCES Meeting_Rooms (floor) ON DELETE CASCADE,
    FOREIGN KEY (booker_id) REFERENCES Bookers (eid) ON DELETE CASCADE,
    FOREIGN KEY (manager_id) REFERENCES Manager (eid) ON DELETE CASCADE
);

-- join
CREATE TABLE Joins (
    employee_id     INTEGER NOT NULL,
    session_room    INTEGER,     
    session_floor   INTEGER,
    session_time    TIME,
    session_date    DATE,
    PRIMARY KEY (employee_id, session_room, session_floor, session_time, session_date),
    FOREIGN KEY (employee_id) REFERENCES Employees (eid),
    FOREIGN KEY (session_room) REFERENCES Sessions (room),
    FOREIGN KEY (session_floor) REFERENCES Sessions (floor),
    FOREIGN KEY (session_time) REFERENCES Sessions (time),
    FOREIGN KEY (session_date) REFERENCES Sessions (date),
    -- check date and time is future
    CONSTRAINT join_future_meeting CHECK (
        session_date > now()::date
        OR session_date = now()::date AND session_time > now()::time
    )
);