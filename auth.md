# Authentication

In order to authenticate with Zoho API, OAuth is used. This requires a one-time
setup using `auth.q`.

To begin, you must register a "client" via [Zoho Developer Console](https://api-console.zoho.com/).
For kdbzoho, you should select a "Self Client" as the client type.

Doing so will generate a Client ID & Client Secret, which will be required when
running `auth.q`.

You will then need to follow the "Self-Client option" of the [Authorization Request](https://www.zoho.com/people/api/oauth-steps.html#step2)
section of Zoho API docs, in other to generate a grant token code.

For scopes required, the following should cover all functionality of kdbzoho:

```
ZOHOPEOPLE.employee.ALL,ZOHOPEOPLE.forms.ALL,ZOHOPEOPLE.timetracker.ALL,ZOHOPEOPLE.leave.ALL
```

Once generated, you will receive a grant token code.

Run `auth.q` & paste in client ID, client secret & grant token at relevant
prompts.

This will create several files in your home directory:

* `.zoho_client_secret`
* `.zoho_client_id`
* `.zoho_refresh_token`

When running kdbzoho, these files will be used to request an "access token",
which will in turn be used for all API requests.

If you need to regenerate refresh token (e.g. due to accidental deletion), you
will need to go through this process again. Likewise if you need to adjust
the scopes granted to token, repeat the process. If client ID & secret files
already exist, `auth.q` will use them rather than prompting for these again.
