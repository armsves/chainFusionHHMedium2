/*
import Time "mo:base/Time";
import Int "mo:base/Int";

actor Echo {
  type Time = Time.Time;
  // Say the given phase.
  public query func say(_phrase : Text) : async Text {
    //let time : Time = Time.now()/1000000000;
    let time : Text = Int.toText(Int.abs(Time.now()));
    return time;
  };
};
*/
import Time "mo:base/Time";
import Int "mo:base/Int";
import Array "mo:base/Array";
import { abs } = "mo:base/Int";
import { now } = "mo:base/Time";
import { setTimer; recurringTimer } = "mo:base/Timer";
//import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import Cycles "mo:base/ExperimentalCycles";
//import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";
//import Time "mo:base/Time";
//import Int "mo:base/Int";

//import the custom types we have in Types.mo
import Types "Types";

//Actor
actor {

    //This method sends a GET request to a URL with a free API we can test.
    //This method returns Coinbase data on the exchange rate between USD and ICP
    //for a certain day.
    //The API response looks like this:
    //  [
    //     [
    //         1682978460, <-- start timestamp
    //         5.714, <-- lowest price during time range
    //         5.718, <-- highest price during range
    //         5.714, <-- price at open
    //         5.714, <-- price at close
    //         243.5678 <-- volume of ICP traded
    //     ],
    // ]

    var historicData : [[Text]] = [];

    //function to transform the response
    public query func transform(raw : Types.TransformArgs) : async Types.CanisterHttpResponsePayload {
        let transformed : Types.CanisterHttpResponsePayload = {
            status = raw.response.status;
            body = raw.response.body;
            headers = [
                {
                    name = "Content-Security-Policy";
                    value = "default-src 'self'";
                },
                { name = "Referrer-Policy"; value = "strict-origin" },
                { name = "Permissions-Policy"; value = "geolocation=(self)" },
                {
                    name = "Strict-Transport-Security";
                    value = "max-age=63072000";
                },
                { name = "X-Frame-Options"; value = "DENY" },
                { name = "X-Content-Type-Options"; value = "nosniff" },
            ];
        };
        transformed;
    };

    private func get_icp_usd_exchange() : async () {

        //1. DECLARE IC MANAGEMENT CANISTER
        //We need this so we can use it to make the HTTP request
        let ic : Types.IC = actor ("aaaaa-aa");

        //2. SETUP ARGUMENTS FOR HTTP GET request

        // 2.1 Setup the URL and its query parameters
        //let ONE_MINUTE : Nat64 = 60;
        //let start_timestamp : Types.Timestamp = 1682978460; //May 1, 2023 22:01:00 GMT
        //let start_timestamp : Types.Timestamp = Time.now()/1000000000;

        //let time : Text = Int.toText(Int.abs(Time.now()/1000000000));

        //let host : Text = "api.exchange.coinbase.com";
        let host : Text = "api.coinbase.com";
        //let url = "https://" # host # "/products/ICP-USD/candles?start=" # time # "&end=" # time # "&granularity=" # Nat64.toText(ONE_MINUTE);

        let url = "https://" # host # "/v2/prices/ICP-USD/spot";
        // 2.2 prepare headers for the system http_request call
        let request_headers = [
            { name = "Host"; value = host # ":443" },
            { name = "User-Agent"; value = "exchange_rate_canister" },
        ];

        // 2.2.1 Transform context
        let transform_context : Types.TransformContext = {
            function = transform;
            context = Blob.fromArray([]);
        };

        // 2.3 The HTTP request
        let http_request : Types.HttpRequestArgs = {
            url = url;
            max_response_bytes = null; //optional for request
            headers = request_headers;
            body = null; //optional for request
            method = #get;
            transform = ?transform_context;
        };

        //3. ADD CYCLES TO PAY FOR HTTP REQUEST

        //The IC specification spec says, "Cycles to pay for the call must be explicitly transferred with the call"
        //IC management canister will make the HTTP request so it needs cycles
        //See: https://internetcomputer.org/docs/current/motoko/main/cycles

        //The way Cycles.add() works is that it adds those cycles to the next asynchronous call
        //"Function add(amount) indicates the additional amount of cycles to be transferred in the next remote call"
        //See: https://internetcomputer.org/docs/current/references/ic-interface-spec/#ic-http_request
        Cycles.add<system>(230_949_972_000);

        //4. MAKE HTTPS REQUEST AND WAIT FOR RESPONSE
        //Since the cycles were added above, we can just call the IC management canister with HTTPS outcalls below
        let http_response : Types.HttpResponsePayload = await ic.http_request(http_request);

        //5. DECODE THE RESPONSE

        //As per the type declarations in `src/Types.mo`, the BODY in the HTTP response
        //comes back as [Nat8s] (e.g. [2, 5, 12, 11, 23]). Type signature:

        //public type HttpResponsePayload = {
        //     status : Nat;
        //     headers : [HttpHeader];
        //     body : [Nat8];
        // };

        //We need to decode that [Nat8] array that is the body into readable text.
        //To do this, we:
        //  1. Convert the [Nat8] into a Blob
        //  2. Use Blob.decodeUtf8() method to convert the Blob to a ?Text optional
        //  3. We use a switch to explicitly call out both cases of decoding the Blob into ?Text
        let response_body : Blob = Blob.fromArray(http_response.body);
        let decoded_text : Text = switch (Text.decodeUtf8(response_body)) {
            case (null) { "No value returned" };
            case (?y) { y };
        };

        //6. RETURN RESPONSE OF THE BODY
        //The API response will looks like this:

        // ("[[1682978460,5.714,5.718,5.714,5.714,243.5678]]")

        //Which can be formatted as this
        //  [
        //     [
        //         1682978460, <-- start/timestamp
        //         5.714, <-- low
        //         5.718, <-- high
        //         5.714, <-- open
        //         5.714, <-- close
        //         243.5678 <-- volume
        //     ],
        // ]
        let now : Text = Int.toText(Int.abs(Time.now() / 1000000000));

        historicData := Array.append(historicData, [[now, decoded_text]]);
        //decoded_text
    };

    let timerDelaySeconds = 20;
    let second = 1_000_000_000;
    /*
  private func execute_timer() : async () {
    Debug.print("right before timer trap");
    Debug.trap("timer trap");
  };
*/
    ignore setTimer<system>(
        #seconds(timerDelaySeconds - abs(now() / second) % timerDelaySeconds),
        func() : async () {
            ignore recurringTimer<system>(#seconds timerDelaySeconds, get_icp_usd_exchange);
            await get_icp_usd_exchange();
        },
    );

    public query func getStoredData() : async [[Text]] {
        return historicData;
    };

};
