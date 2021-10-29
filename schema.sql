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
    hdate DATE,
    temp FLOAT(2) CHECK (temp >= 34.0 AND temp <= 43.0),
    fever BOOLEAN,
    PRIMARY KEY (eid, hdate),
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
    mfloor   INTEGER,
    rname   VARCHAR(100),
    did     INTEGER NOT NULL,
    PRIMARY KEY (room, mfloor),
    FOREIGN KEY (did) REFERENCES Departments(did)
);

-- updates
CREATE TABLE Updates (
    manager_id  INTEGER NOT NULL,
    room        INTEGER,
    ufloor       INTEGER,
    udate        DATE,
    new_cap     INTEGER,
    PRIMARY KEY (manager_id, room, ufloor, udate),
    FOREIGN KEY (manager_id) REFERENCES Managers (eid),
    FOREIGN KEY (room, ufloor) REFERENCES Meeting_Rooms (room, mfloor)
);

-- session (with rname, with books, with manager)
CREATE TABLE Sessions (
    room    INTEGER,
    sfloor   INTEGER,
    stime    TIME,
    sdate    DATE,
    booker_id INTEGER NOT NULL,
    manager_id INTEGER UNIQUE,
    PRIMARY KEY (room, sfloor, stime, sdate),
    FOREIGN KEY (room, sfloor) REFERENCES Meeting_Rooms (room, mfloor) ON DELETE CASCADE,
    FOREIGN KEY (booker_id) REFERENCES Bookers (eid) ON DELETE CASCADE,
    FOREIGN KEY (manager_id) REFERENCES Managers (eid) ON DELETE CASCADE
);

-- join
CREATE TABLE Joins (
    eid     INTEGER NOT NULL,
    room    INTEGER,     
    jfloor   INTEGER,
    jtime    TIME,
    jdate    DATE,
    PRIMARY KEY (eid, room, jfloor, jtime, jdate),
    FOREIGN KEY (eid) REFERENCES Employees (eid),
    FOREIGN KEY (room, jfloor, jtime, jdate) REFERENCES Sessions (room, sfloor, stime, sdate),
    -- check date and time is future
    CONSTRAINT join_future_meeting CHECK (
        jdate > now()::date
        OR jdate = now()::date AND jtime > now()::time
    )
);
