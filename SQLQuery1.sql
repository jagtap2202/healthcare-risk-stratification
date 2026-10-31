Create database healthcare;
use healthcare;
create table diagnoses(
diagnosisID int primary key,
diagnosesName varchar(255)
);

create table outcomes(
OutcomeID int primary key,
OutcomeName varchar(255)
);

create table patients(
patientID int primary key,
Name varchar(255),
Age int,
gender char(1),
DiagnosisID int,
AdmissionDate Date,
DischargeDate date,
OutcomeId int,
Treatmentcost decimal(10,2),
foreign key(diagnosisID) references Diagnoses(diagnosisID),
foreign key(OutcomeID) references outcomes(outcomeID)
);

create table Labs(
LabId int primary key,
PatientId int,
TestName varchar(255),
Result decimal(10,2),
NormalRange varchar(255),
foreign key(PatientID) references patients(PatientID)
);

select * from patients;


bulk insert patients
From'C:\Users\jagta\OneDrive\Desktop\Projects\Project 1\patients.csv'
with(
firstrow=2, 
rowterminator='0x0a',
fieldterminator=',',
datafiletype='char'
);

bulk insert outcomes
From'C:\Users\jagta\OneDrive\Desktop\Projects\Project 1\outcomes.csv'
with(
firstrow=2, 
rowterminator='0x0a',
fieldterminator=',',
datafiletype='char'
);

bulk insert labs
From'C:\Users\jagta\OneDrive\Desktop\Projects\Project 1\labs.csv'
with(
firstrow=2, 
rowterminator='0x0a',
fieldterminator=',',
datafiletype='char'
);

bulk insert diagnoses
From'C:\Users\jagta\OneDrive\Desktop\Projects\Project 1\diagnoses.csv'
with(
firstrow=2, 
rowterminator='0x0a',
fieldterminator=',',
datafiletype='char'
);

--Retrieve Detailed patient Lab history

select p.patientid, p.Name, d.DiagnosesName , o.outcomename, l.testname, l.result, l.Normalrange
from patients p
join diagnoses d on p.diagnosisid=d.diagnosisid
join outcomes o on p.outcomeid=o.outcomeid
join labs l on p.patientid = l.patientid
order by p.patientid, l.testname;

--Average lab results by diagnosis

select d.diagnosesname, l.testname, avg(l.result) as Avgresult
from patients p
join diagnoses d on p.diagnosisid=d.diagnosisid
join labs l on p.patientID = l.patientid
group by d.diagnosesname, l.testname;

--Finding Abnormal lab results
select p.patientid, p.name , count(*) as Abnormalcount
from patients p
join labs l on p.patientid =l.patientid 
where (l.testname ='Blood Sugar' and l.result>120) or
(l.testname ='Cholestrol' and l.result<200) or
(l.testname ='Hemoglobin' and l.result<13)
group by p.patientid, p.name 
order by Abnormalcount desc;

--Diagnoses with Highest treatment cost

select d.diagnosesname, sum(p.treatmentcost) as TotalCost
from patients p
join diagnoses d on p.diagnosisid = d.diagnosisid
group by d.diagnosesname
order by TotalCost Desc;


--Patients at Risk by age and gender
--To remove the extra characters from the last column of outcome table
update outcomes
set outcomename = replace(replace(outcomename, char(13), ''), char(10), '');
--check the length of the characters and remove any extra spaces
select outcomeid, outcomename, len(outcomename) as len,
       ascii(right(outcomename, 1)) as last_char
from outcomes;

select p.patientid, p.name, p.age, d.diagnosesname, o.outcomename
from patients p 
join diagnoses d on p.diagnosisid = d.diagnosisid
join outcomes o on p.outcomeId = o.outcomeID
where p.age>65 and o.outcomename <> 'Recovered';

---check the character length
select outcomeid, outcomename,
       len(outcomename) as len,
       ascii(right(outcomename, 1)) as last_char
from outcomes;

--Lab trends over time for a specific patient

select l.testname, l.result, p.admissiondate
from labs l
join patients p on l.patientid = p.patientid 
where p.patientid = 10
order by p.admissiondate;

--Distribution of outcomes by diagnosis

select d.DiagnosesName, o.outcomename, count(*) as outcomecount
from patients p
join diagnoses d on p.diagnosisID =d.diagnosisId
join outcomes o on p.outcomeId =o.outcomeId
group by d.diagnosesname, o.outcomename
order by d.diagnosesname, o.outcomename desc;

