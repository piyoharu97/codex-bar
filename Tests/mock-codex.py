#!/usr/bin/env python3
import json, sys
initialized = False
for line in sys.stdin:
    request = json.loads(line)
    if request['method'] == 'initialize':
        assert request['params']['clientInfo']['name'] == 'codex_quota_widget'
        print(json.dumps({'id':request['id'],'result':{}}), flush=True)
    elif request['method'] == 'initialized':
        initialized = True
    elif request['method'] == 'account/rateLimits/read':
        assert initialized
        print(json.dumps({'method':'ignored/notification','params':{}}),flush=True)
        payload = {'id':request['id'], 'result':{'rateLimits':{'primary':{'usedPercent':40,'windowDurationMins':10080},'secondary':{'usedPercent':25,'windowDurationMins':300}}}}
        text = json.dumps(payload)
        # Exercise partial stdout reads.
        sys.stdout.write(text[:12]); sys.stdout.flush()
        sys.stdout.write(text[12:]+'\n'); sys.stdout.flush()
    else:
        raise RuntimeError('Unexpected request: no inference or auth mutations permitted')
