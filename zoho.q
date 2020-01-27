/load requests lib, Zoho API needs redirects,urlencode etc.
\l lib/req_0.1.3.q

\d .zh

/* CONFIGURATION */

user:"jonathon.mcmurray@aquaq.co.uk"                                                //user ID (email)
cfg:update days:"I"$" "vs'days from ("S*I";1#",")0:`:config.csv;                    //load config file
cfg:`days xkey ungroup cfg;                                                         //create keyed table for config per day
al:`322556000001913407                                                              //annual leave job id
ph:`322556000001913389                                                              //public holiday job id
params:.Q.def[`month`user!(`month$.z.D;`$user)] first each .Q.opt .z.x;             //parse command line args
@[`.zh.params;`user;string];                                                        //convert username back to string

/* INTERNALS */

url:"http://people.zoho.com/people/api/"                                            //base url for API requests
token:first read0`:zohotoken                                                        //read auth token
ad:enlist[`authtoken]!enlist token;                                                 //authentication dictionary base

api:{[m;p] /m-method,p-params
  r:.req.get[url,m,"?",.url.enc ad,p;()!()];                                        //pass params urlencoded, use .req.get for redirects etc.
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
jmap:exec (`$jobid)!" - "sv/:flip (clientname;jobname) from getjobs params`user;    //map jobids to names

getleave:{[u] /u-user(email)
  /* get dictionary of full & half days of leave for given user */
  lg"Getting leave for ",u;
  w:`searchColumn`searchValue!("EMPLOYEEMAILALIAS";u);                              //params dict
  h:api["forms/P_ApplyLeave/getRecords";w];                                         //send request
  h:update f:"D"$From,t:"D"$To,d:"F"$Daystaken from raze value raze h;              //parse to table & update types
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

logmonth:{[u;m] /u-user(email),m-month
  /* log all days for a month */
  lg"Logging for month ",string[m]," ...";
  d:range . 0 -1+.Q.addmonths[`date$m;0 1];                                         //generate days in month
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

\d .


if[`jobs in key .zh.params;
   show `jobname`clientname`jobid#.zh.getjobs .zh.params`user;
   exit 0;
  ];


.zh.logmonth . .zh.params`user`month;                                                //log the specified month (default this month)
