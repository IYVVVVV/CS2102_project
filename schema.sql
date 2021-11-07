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
    eid SERIAL,
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
    FOREIGN KEY(eid) REFERENCES Employees(eid) ON DELETE CASCADE ON UPDATE CASCADE
);

-- booker
CREATE TABLE Bookers (
    eid INTEGER,
    PRIMARY KEY(eid),
    FOREIGN KEY(eid) REFERENCES Employees(eid) ON DELETE CASCADE ON UPDATE CASCADE
);

-- senior
CREATE TABLE Seniors (
    eid INTEGER,
    PRIMARY KEY(eid),
    FOREIGN KEY(eid) REFERENCES Bookers(eid) ON DELETE CASCADE ON UPDATE CASCADE
);

-- manager 
CREATE TABLE Managers (
    eid INTEGER,
    PRIMARY KEY(eid),
    FOREIGN KEY(eid) REFERENCES Bookers(eid) ON DELETE CASCADE ON UPDATE CASCADE
);

-- health declaration
CREATE TABLE Health_declarations (
    eid INTEGER,
    hdate DATE,  -- not null since primary
    htemp FLOAT(2),
    fever BOOLEAN,
    PRIMARY KEY (eid, hdate),
    FOREIGN KEY (eid) REFERENCES Employees(eid) ON UPDATE CASCADE,
    -- temperature should be in reasonable range
    CONSTRAINT proper_htemp CHECK (htemp >= 34.0 AND htemp <= 43.0),
    -- fever only if htemp >= 37.5
    CONSTRAINT derive_fever_correctly CHECK (
        (htemp < 37.5 AND fever = FALSE) OR (htemp >= 37.5 and fever = TRUE)),
    -- cannot declare a future health condition
    CONSTRAINT disallow_future_declaration CHECK (hdate <= now()::date)
);

-- contacts
CREATE TABLE Contacts (
    eid INTEGER,
    contact char(8) NOT NULL,
    PRIMARY KEY(eid, contact),
    FOREIGN KEY (eid) REFERENCES Employees(eid) ON DELETE CASCADE,
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
    manager_id INTEGER,
    PRIMARY KEY (room, sfloor, stime, sdate),
    FOREIGN KEY (room, sfloor) REFERENCES Meeting_Rooms (room, mfloor) ON DELETE CASCADE,
    FOREIGN KEY (booker_id) REFERENCES Bookers (eid) ON DELETE CASCADE,
    FOREIGN KEY (manager_id) REFERENCES Managers (eid) ON DELETE CASCADE,
    -- session should be hourly
    CONSTRAINT hourly_session_time CHECK (
        stime in ('00:00', '01:00', '02:00', '03:00', '04:00', '05:00', '06:00',
                  '07:00', '08:00', '09:00', '10:00', '11:00', '12:00', 
                  '13:00', '14:00', '15:00', '16:00', '17:00', '18:00',
                  '19:00', '20:00', '21:00', '22:00', '23:00', '24:00'))
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
    FOREIGN KEY (room, jfloor, jtime, jdate) REFERENCES Sessions (room, sfloor, stime, sdate)
);

-- contact_tracing
CREATE TABLE Close_Contacts (
    eid         INTEGER,
    affect_date DATE,
    PRIMARY KEY (eid, affect_date),
    FOREIGN KEY (eid) REFERENCES Employees (eid)
);



