DROP TABLE IF EXISTS
    Employees, Contacts, Health_declarations, Departments, Meeting_Rooms, Updates, Juniors, Bookers, Seniors, Managers, Sessions, Joins;

-- department
CREATE TABLE Departments (
    did     INTEGER,
    dname   VARCHAR(100) NOT NULL,
    PRIMARY KEY (did)
);

-- employee (works in)
CREATE TABLE Employees (
    eid INTEGER,
    ename VARCHAR(50) NOT NULL,
    email VARCHAR(50) UNIQUE NOT NULL,
    resigned_date DATE,
    did INTEGER NOT NULL,
    PRIMARY KEY(eid),
    FOREIGN KEY(did) REFERENCES Departments(did),
    -- email should be in form 'xxx@yyy.zzz'
    CONSTRAINT proper_email CHECK (email ~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$'),
    -- resigned_date should either be NULL, or some previous date
    CONSTRAINT proper_resigned_date CHECK (resigned_date IS NULL OR resigned_date <= now()::date)
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
    hdate DATE,  -- not null since primary
    htemp FLOAT(2),
    fever BOOLEAN,
    PRIMARY KEY (eid, hdate),
    FOREIGN KEY (eid) REFERENCES Employees(eid),
    -- temperature should be in reasonable range
    CONSTRAINT proper_htemp CHECK (htemp >= 34.0 AND htemp <= 43.0),
    -- -- fever only if htemp >= 38.0
    CONSTRAINT derive_fever_correctly CHECK (
        (htemp < 38.0 AND fever = FALSE) OR (htemp >= 38.0 and fever = TRUE))
);

-- contacts
CREATE TABLE Contacts (
    eid INTEGER,
    contact TEXT NOT NULL,
    PRIMARY KEY(eid, contact),
    FOREIGN KEY (eid) REFERENCES Employees(eid),
    -- contact number should be an 8 digits text
    CONSTRAINT proper_contact CHECK (contact ~* '^[0-9]{8}$')
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

-- booking
NewSessionBook {
    newsid          INTEGER,
    booker          INTEGER,
    sessionRoom     INTEGER,
    sessionFloor    INTEGER
    ndate           DATE,
    ntime           TIME,
    PRIMARY KEY (newsid),
    FOREIGN KEY (booker) REFERENCES Employees (eid),
    FOREIGN KEY (sessionRoom) REFERENCES Meeting_Rooms (room),
    FOREIGN KEY (sessionFloor) REFERENCES MeetingRooms (mfloor)
}

-- meeting room capacity
CREATE TABLE MeetingRoomCapacity {
    room    INTEGER,
    mfloor  INTEGER,
    mdate   DATE,
    mtime   TIME,
    mcapacity   INTEGER,
    PRIMARY KEY (room, mfloor, mdate, mtime),
    FOREIGN KEY (room) REFERENCES Meeting_Rooms (room),
    FOREIGN KEY (mfloor) REFERENCES Meeting_Rooms (mfloor)
}

