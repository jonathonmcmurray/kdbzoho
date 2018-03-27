/ settings
USR:"jonathon.mcmurray@aquaq.co.uk"
TOK:first read0`:zohotoken

/load requests lib, Zoho API needs redirects,urlencode etc.
\l req.q

/load config
CFG:update days:"I"$" "vs'days from ("S*I";1#",")0:`:config.csv;                    //load config file
CFG:`days xkey ungroup CFG;                                                         //create keyed table for config per day
MNTH:`month$.z.D;                                                                   //assume this month

URL:"http://people.zoho.com/people/api/"                                            //basic URL
apiurl:{[x;y]URL,x,"/",y,"?"}                                                       //get api URL for a method
zdate:{[d]ssr[string d;".";"-"]}                                                    //convert date to Zoho
lg:{-1 string[.z.T]," - ",x}                                                        //logging function

lg"Getting public holidays...";
HOLS:.req.get[;()!()]apiurl["leave";"getHolidays"],.req.urlencode `authtoken`userId!(TOK;USR)
HOLS:"D"$.j.k[HOLS][`response][`result][`fromDate];                                 //get holiday dates & convert to KDB type

getleave:{[]
  lg"Getting leave for ",USR;
  w:`authtoken`searchColumn`searchValue!(TOK;"EMPLOYEEMAILALIAS";USR);              //params dict
  h:.req.get[;()!()] apiurl["forms/P_ApplyLeave";"getRecords"],.req.urlencode w;    //send request
  h:raze value raze .j.k[h][`response][`result];                                    //parse to table
  :exec d!l from update d:"D"$From,l:"F"$Daystaken from h;                          //return dict of start date & length
 }

loghours:{[d;j;h] /d-date,j-jobid,h-hours
  lg"Logging ",string[h]," hours on ",d," for job: ",string[j];
  w:`authtoken`user`workDate`billingStatus`jobId`hours!(TOK;USR;d;"billable";j;h);  //build dict
  :.req.get[apiurl["timetracker";"addtimelog"],.req.urlencode w;()!()];             //send HTTP request
 }

logday:{[d;f] /d-date,f-fraction worked
  h:f*CFG[d mod 7]`hours;                                                           //adjust hours if off for part of day
  loghours[zdate d;CFG[d mod 7]`job;h];                                             //read from config & log hours
 }

logmonth:{[m] /m-month
  lg"Logging for month ",string[m]," ...";
  d:first[a]+til last[a]-first a:.Q.addmonths[`date$m;0 1];                         //generate days in month
  d@:where 1<d mod 7;                                                               //filter out weekends
  d:d except HOLS;                                                                  //filter out public holidays
  l:getleave[];                                                                     //get leave to be applied
  l:(n:d inter k:key l)#l;                                                          //filter to leave within date range
  c:count[d]#1.;                                                                    //begin with full day every day
  c:@[c;d?n;-;l n];                                                                 //subtract leave
  if[any 0>c;                                                                       //check for extended leave
     c:@[c;w+til each 1+`int$abs c w:where 0>c;:;0];                                //spread leave over following days
    ];
  d:d w:where 0<>c;                                                                 //ignore days off
  c:c w;                                                                            //ignore days off
  logday'[d;c];                                                                     //log all days
  lg"Finished log for ",string m;
 }

logmonth MNTH;                                                                      //log the current month
