\l lib/os_0.1.4.q
\l lib/req_0.1.4.q

cid:@[.os.hread;`.zoho_client_id;{1"Enter Client ID: ";read0 0}];
cs:@[.os.hread;`.zoho_client_secret;{1"\nEnter Client Secret: ";read0 0}];
1"\nEnter grant token: ";gt:read0 0;

auth:.req.post["https://accounts.zoho.com/oauth/v2/token";enlist["Content-Type"]!enlist .req.ty`form;.url.enc `grant_type`client_id`client_secret`code!(`authorization_code;cid;cs;gt)];

if[`error in key auth;
	-2"Error recieved from Zoho API: ",auth`error;
	exit 1];

.os.hwrite[`.zoho_client_id;cid]
.os.hwrite[`.zoho_client_secret;cs]
.os.hwrite[`.zoho_access_token;auth`access_token]
.os.hwrite[`.zoho_refresh_token;auth`refresh_token]

exit 0
