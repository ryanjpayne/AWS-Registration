var response = require('cfn-response');
          
exports.getToken = async function (baseURL, clientId, clientSecret, controller = undefined) {
    const resp = await fetch(`${baseURL}/oauth2/token`, {
        method: 'POST',
        body: `client_id=${clientId}&client_secret=${clientSecret}`,
        headers: {
            'content-type': 'application/x-www-form-urlencoded'
        },
        signal: controller,
    });

    const data = await resp.json();

    if (resp.ok) {
        return data.access_token
    }
    throw new Error(`Invalid response: ${resp.status} ${JSON.stringify(data)}`)
}

exports.sendAWSRegistration = async function (baseURL, token, event, controller = undefined) {
    // generate content from parameters
    var registrationBody = {
        account_number: event.ResourceProperties.AccountID,
        iam_role_arn: event.ResourceProperties.RoleArn,
        iam_external_id: event.ResourceProperties.ExternalID,
        kms_alias: event.ResourceProperties.KmsAlias,
        batch_regions: []
    };

    event.ResourceProperties.Regions.split(",").forEach((r) => {
        registrationBody.batch_regions.push({ region: r, job_definition_name: "crowdstrike-side-scanning", job_queue: "crowdstrike-side-scanning" })
    });

    var body = JSON.stringify({ aws_accounts: [registrationBody] });
    console.log(body);

    const resp = await fetch(`${baseURL}/snapshots/entities/accounts/v1`, {
        method: 'POST',
        body,
        headers: {
            'Authorization': `Bearer ${token}`,
            'content-type': 'application/json'
        },
        signal: controller,
    });
    console.log(`registration status code: ${resp.status}`);
    var body = await resp.json();

    return body
}

exports.handler = async function (event, context) {
    console.log(JSON.stringify(event))

    if (event.RequestType == "Create" || event.RequestType == "Update") {
        const signal = AbortSignal.timeout(5000);
        try {
            var token = await exports.getToken(process.env.BASE_URL, process.env.CLIENT_ID, process.env.CLIENT_SECRET, signal);
            var regResponse = await exports.sendAWSRegistration(process.env.BASE_URL, token, event, signal);
            console.log(JSON.stringify(regResponse));
        } catch (error) {
            if (signal.aborted) {
                console.log('timed out communicating with the falcon api')
            } else {
                console.error(error);
            }
            console.log(`error submitting account data to crowdstrike API. Please use the console`);
        }
    } else {
        console.log("deletes are no-ops");
    }
    // send
    await response.send(event, context, response.SUCCESS, {});
};