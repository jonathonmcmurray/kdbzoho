# kdbzoho

Script for logging time on Zoho People from KDB

To use, you will need an authentication token. Get this from [here](https://accounts.zoho.com/apiauthtoken/create?SCOPE=zohopeople/peopleapi) (must be signed in to Zoho for this to work) and save in a text file named `zohotoken` in the directory

Edit `config.csv` with relevent jobIds (a future update will help determining correct jobIds), days (2-6 being Mon-Fri) and hours for job (currently multiple jobs on a given day will likely not work, but is untested)

Takes into account public holidays & annual leave - these will not be logged in current version, but rather left blank.


## Upcoming features

* Log public holidays & annual leave appropriately
* Handle case where annual leave spans over the boundary between months
* Display previous time logs etc.
* Find correct jobids
* Submit timesheets
