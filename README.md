# kdbzoho

Script for logging time on Zoho People from KDB

Before use, authentication must be setup via `auth.q`, see [auth.md](auth.md) for details.

You will need to provide your username (i.e. email address associated with your account). You can do this with the `-user user@domain.ext` command line paramter, or you can change the default by editing the `user` variable near the top of `zoho.q`

Edit `config.csv` with relevent jobIds (run `q zoho.q -jobs` to see jobs assigned to you), days (2-6 being Mon-Fri) and hours for job (currently multiple jobs on a given day will likely not work, but is untested)

Takes into account public holidays & annual leave - the job IDs for these can be modified in `zoho.q` as required.

## Usage

1. Set up authentication as per [auth.md](auth.md)
2. Run `q zoho.q -jobs` to identify required jobids
3. Modify `config.csv` with these jobids
4. Modify `al` and `ph` variables in `zoho.q` with Annual Leave & Public Holiday jobids as necessary
5. Run `q zoho.q -user yourname@yourcompany.ext` to perform logging for current month (or modify default user & leave out `-user yourname@yourcompany.ext`)
6. Check submitted time logs & submit your timesheets

## Warning

The author is not responsible for any mistakes made in your timesheets, please ensure accuracy before submitting.

## Command line args

* `-jobs` : display jobs assigned to user
* `-user` : overwrite default user email address
* `-month` : overwrite default month (default = current month)

## Upcoming features

* Display previous time logs etc.
