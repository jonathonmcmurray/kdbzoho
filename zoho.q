/load requests lib, Zoho API needs redirects,urlencode etc.
\l lib/req_0.1.4.q
/load OS lib, for reading auth tokens etc.
\l lib/os_0.1.4.q

\d .zh

/* CONFIGURATION */

user:"jonathon.mcmurray@aquaq.co.uk"                                                //user ID (email)
cfg:update days:"I"$" "vs'days from ("S*I";1#",")0:`:config.csv;                    //load config file
cfg:`days xkey ungroup cfg;                                                         //create keyed table for config per day
al:`322556000000129615                                                              //annual leave job id
ph:`322556000001506017                                                              //public holiday job id
params:.Q.def[`month`user!(`month$.z.D;`$user)] first each .Q.opt .z.x;             //parse command line args
@[`.zh.params;`user;string];                                                        //convert username back to string
retries:5;                                                                          //number of retries

.req.PARSE:0b;                                                                      //disable reQ auto-parsing to allow custom error handling
.req.SIGNAL:0b;                                                                     //disable reQ signalling on HTTP error codes for custom error handling

/* INTERNALS */

url:"http://people.zoho.com/people/api/"                                            //base url for API requests
accountsurl:"https://accounts.zoho.com";

cid:@[.os.hread;`.zoho_client_id;{-2 x,"\nPlease run auth.q to generate tokens";exit 1}];
cs:@[.os.hread;`.zoho_client_secret;{-2 x,"\nPlease run auth.q to generate tokens";exit 1}];
rt:@[.os.hread;`.zoho_refresh_token;{-2 x,"\nPlease run auth.q to generate tokens";exit 1}];

auth:.j.k last .req.post[accountsurl,"/oauth/v2/token?",.url.enc `refresh_token`client_id`client_secret`grant_type!(rt;cid;cs;`refresh_token);()!();()];
if[`error in key auth;
	-2"Error from Zoho API: ",auth`error;
	exit 1];
.req.def[`Authorization]:"Zoho-oauthtoken ",auth`access_token;

sleep:{x:string x; system("sleep ",x;"timeout /t ",x," >nul")[.z.o in `w32`w64]}    //platform agnostic sleep

api:{[m;p] /m-method,p-params
  i:0;s:0;
  while[(i<retries)&s<>200;
   r:.req.get[url,m,"?",.url.enc p;()!()];                                          //pass params urlencoded, use .req.get for redirects etc.
   h:r[0];r:.j.k r[1];                                                              //split headers & result body, parsing json
   if[200<>s:h`status;                                                              //check if response is OK
    e:r[`response][`errors];                                                        //extract API error
    lg"Zoho API error [",string[e`code],"] ",e`message;                             //output error returned from Zoho API
    if[7202=e`code;
     lg"Please provide valid authentication token";                                 //if error is bad token, no point retrying
     exit 1;
    ];
    lg"Retrying in 10 minutes";
    sleep 600;                                                                      //wait 10 minutes then try again
    i+:1;
   ];
  ];
  :r[`response][`result];                                                           //parse result and return
 }

zdate:{[d]ssr[string d;".";"-"]}                                                    //convert date to Zoho
range:{x+til 1+y-x}                                                                 //generate date range
lg0:{1 string[.z.T]," - ",x}                                                        //logging function (no new line)
lg:{lg0 x,"\n"}                                                                     //wrapper for logging with new line

lg"Getting public holidays...";
hols:api["leave/getHolidays"]enlist[`userId]!enlist params`user                     //get public hols from API
hols:"D"$hols[`fromDate];                                                           //get holiday dates & convert to KDB type

/* PUBLIC API FUNCTIONS */

getjobs:{[u] /u-user(email)
  /* get table of jobs assigned to given user */
  lg"Getting jobs for ",u;
  j:api["timetracker/getjobs"]enlist[`assignedTo]!enlist u;                         //perform API request
  :lower[c] xcol (c:(union/)key each j)#/:j;                                        //return as table
 }
jmap:exec (`$jobid)!" - "sv/:flip (clientname;jobname) from jobs:getjobs params`user; //map jobids to names

getleave:{[u] /u-user(email)
  /* get dictionary of full & half days of leave for given user */
  lg"Getting leave for ",u;
  w:`searchColumn`searchValue!("EMPLOYEEMAILALIAS";u);                              //params dict
  h:api["forms/P_ApplyLeave/getRecords";w];                                         //send request
  h:update f:"D"$From,t:"D"$To,d:"F"$Daystaken from (uj/)value raze h;              //parse to table & update types
  f:exec raze .zh.range'[f;t] from h where d>0.5;                                   //get all dates with full days off
  d:exec raze f from h where d=0.5;                                                 //get all dates with half days off
  :`full`half!(f;d);                                                                //return dictionary
  :exec d!l from update d:"D"$From,l:"F"$Daystaken from h;                          //return dict of start date & length
 }

loghours:{[u;d;j;h] /u-user(email),d-date,j-jobid,h-hours
  /* log a set of hours for particular job */
  lg"Logging ",string[h]," hours on ",d," for job: ",string[j]," (",jmap[j],")";
  w:`user`workDate`billingStatus`jobId`hours!(u;d;"billable";j;h);                  //params dict
  :api["timetracker/addtimelog";w];                                                 //send API request
 }

logday:{[u;d;f] /u-user,d-date,f-fraction worked
  /* log the hours of a given day */
  h:f*cfg[d mod 7]`hours;                                                           //adjust hours if off for part of day
  loghours[u;zdate d;cfg[d mod 7]`job;h];                                           //read from config & log hours
 }

logph:{[u;d] /u-user(email),d-date
  /* log a day as public holiday */
  loghours[u;zdate d;ph;8];                                                         //log 8 hours with public holiday job id
 }

logal:{[u;d;f] /u-user(email),d-date,f-fraction
  /* log a day (or partial day) as annual leave */
  loghours[u;zdate d;al;f*8];                                                       //log annual leave
 }

removeone:{[r] /r-time log record
  lg"Removing log for ",r[`jobName]," on ",r`workDate;
  api["timetracker/deletetimelog";enlist[`timeLogId]!enlist r`timelogId];
 }

getexisting:{[u;s;e] /u-user(email),s-start,e-end
  :api["timetracker/gettimelogs";`user`fromDate`toDate!(u;zdate s;zdate e)];        //get timelogs already made
 }

logmonth:{[u;m] /u-user(email),m-month
  /* log all days for a month */
  lg"Logging for month ",string[m]," ...";
  d:range . 0 -1+.Q.addmonths[`date$m;0 1];                                         //generate days in month
  r:getexisting[u;min d;max d];                                                     //remove any existing time logs to replace
  if[count[r]&`replace in key .zh.params;
   lg"Found ",string[count r]," existing time logs, removing";
   removeone'[r];
  ];
  if[count[r]&not `replace in key .zh.params;
   lg"Found ",string[count r]," existing time logs, skipping those dates";
   d:d except "D"$r@\:`workDate;
  ];
  d@:where 1<d mod 7;                                                               //filter out weekends
  h:d inter hols;                                                                   //get list of public holidays in month
  d:d except hols;                                                                  //filter out public holidays
  l:getleave[u];                                                                    //get leave to be applied
  a:d inter l`full;                                                                 //list of full annual leave days
  d:d except l`full;                                                                //filter out full days off
  c:count[d]#1.;                                                                    //begin with full day every day
  c:@[c;d?f:d inter l`half;:;0.5];                                                  //apply half days
  logday[u]'[d;c];                                                                  //log all days
  if[count h;logph[u]'[h]];                                                         //log public holidays
  if[count a,f;logal[u]'[a,f;(count[a]#1.),count[f]#0.5]];                          //log annual leave
  lg"Finished log for ",string m;
 }

formatdate:{[d]
	months:("Jan";"Feb";"Mar";"Apr";"May";"Jun";"Jul";"Aug";"Sep";"Oct";"Nov";"Dec");
	:"-" sv (string `dd$d;months -1+`mm$d;string `year$d);
 }

timesheet:{[u;m] /u-user(email),m-month
	/* create timesheet for the month & submit for approval */
	p:()!();
	p[`user]:u;
	p[`fromDate]:zdate fd:`date$m;
	p[`toDate]:zdate td:-1+`date$m+1;
	p[`timesheetName]:"Timesheet (",formatdate[fd]," - ",formatdate[td],")";
	p[`sendforApproval]:"true";
	// check for an existing timesheet
	ts:.zh.api["timetracker/gettimesheet";`user`fromDate`toDate#p];
	if[count ts;
		lg"Timesheet already exists, ID ",first ts`recordId;
		tsid:enlist[`timesheetId]!enlist first ts`recordId;
	];
	if[not count ts;
		tsid:.zh.api["timetracker/createtimesheet";p];
	];
	// retrieve the timesheet details & display them to user
	ts:.zh.api["timetracker/gettimesheetdetails";tsid];
	details:`listName`projectName`totalHours`billHours`nonbillHours`fromDate`toDate#ts`details;
	show @[details;`totalHours`billHours`nonbillHours;%;60];
 }

\d .


if[`jobs in key .zh.params;
  show `jobname`clientname`projectname`jobid#.zh.jobs;
  ];

if[not `jobs in key .zh.params;
  .zh.logmonth . .zh.params`user`month;                                                //log the specified month (default this month)
	ts:.zh.timesheet . .zh.params`user`month;																							 //create & submit timesheet
  ];

if[not `noexit in key .zh.params;
  exit 0;
  ];
