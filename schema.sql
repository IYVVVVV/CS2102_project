DROP TABLE IF EXISTS
    Employees, Contacts, Health_declarations, Departments, Meeting_Rooms, Updates, Juniors, Bookers, Seniors, Managers, Sessions, Joins;

-- department
CREATE TABLE Departments (
    did     INTEGER,
    dname   VARCHAR(100),
    PRIMARY KEY (did)
);

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

-- junior
CREATE TABLE Juniors (
    eid INTEGER,
    PRIMARY KEY(eid),
    FOREIGN KEY(eid) REFERENCES Employees(eid) ON DELETE CASCADE
);

-- booker
CREATE TABLE Bookers (
    eid INTEGER,
    PRIMARY KEY(eid),
    FOREIGN KEY(eid) REFERENCES Employees(eid) ON DELETE CASCADE
);

-- senior
CREATE TABLE Seniors (
    eid INTEGER,
    PRIMARY KEY(eid),
    FOREIGN KEY(eid) REFERENCES Bookers(eid) ON DELETE CASCADE
);

-- manager 
CREATE TABLE Managers (
    eid INTEGER,
    PRIMARY KEY(eid),
    FOREIGN KEY(eid) REFERENCES Bookers(eid) ON DELETE CASCADE
);

-- health declaration
CREATE TABLE Health_declarations (
    eid INTEGER,
    date DATE,
    temp FLOAT(2) CHECK (temp >= 34.0 AND temp <= 43.0),
    fever BOOLEAN,
    PRIMARY KEY (eid, date),
    FOREIGN KEY (eid) REFERENCES Employees(eid)
);

-- contacts
CREATE TABLE Contacts (
    eid INTEGER,
    contact TEXT,
    PRIMARY KEY(eid, contact),
    FOREIGN KEY (eid) REFERENCES Employees(eid)
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
    FOREIGN KEY (manager_id) REFERENCES Managers (eid),
    FOREIGN KEY (room, floor) REFERENCES Meeting_Rooms (room, floor)
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
    FOREIGN KEY (room, floor) REFERENCES Meeting_Rooms (room, floor) ON DELETE CASCADE,
    FOREIGN KEY (booker_id) REFERENCES Bookers (eid) ON DELETE CASCADE,
    FOREIGN KEY (manager_id) REFERENCES Managers (eid) ON DELETE CASCADE
);

-- join
CREATE TABLE Joins (
    eid     INTEGER NOT NULL,
    room    INTEGER,     
    floor   INTEGER,
    time    TIME,
    date    DATE,
    PRIMARY KEY (eid, room, floor, time, date),
    FOREIGN KEY (eid) REFERENCES Employees (eid),
    FOREIGN KEY (room, floor, time, date) REFERENCES Sessions (room, floor, time, date),
    -- check date and time is future
    CONSTRAINT join_future_meeting CHECK (
        date > now()::date
        OR date = now()::date AND time > now()::time
    )
);