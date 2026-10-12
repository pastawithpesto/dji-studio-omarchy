"""Fixed policy oracles and fault fixtures. No live network, PR code or merges."""
import copy
import contextlib
import io
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import types
import unittest
from unittest.mock import patch
from urllib.parse import parse_qs, urlsplit

import worker as W

HEAD, BASE, MERGE = 'a' * 40, 'b' * 40, 'c' * 40


def protection():
    # Literal observed root policy oracle, independent of the worker builder.
    return json.loads('''{"url":"https://api.github.com/repos/pastawithpesto/dji-studio-omarchy/branches/main/protection","required_status_checks":{"url":"https://api.github.com/repos/pastawithpesto/dji-studio-omarchy/branches/main/protection/required_status_checks","strict":true,"contexts":["agent-review/verified"],"contexts_url":"https://api.github.com/repos/pastawithpesto/dji-studio-omarchy/branches/main/protection/required_status_checks/contexts","checks":[{"context":"agent-review/verified","app_id":null}]},"required_pull_request_reviews":{"url":"https://api.github.com/repos/pastawithpesto/dji-studio-omarchy/branches/main/protection/required_pull_request_reviews","dismiss_stale_reviews":true,"require_code_owner_reviews":false,"require_last_push_approval":false,"required_approving_review_count":0},"required_signatures":{"url":"https://api.github.com/repos/pastawithpesto/dji-studio-omarchy/branches/main/protection/required_signatures","enabled":false},"enforce_admins":{"url":"https://api.github.com/repos/pastawithpesto/dji-studio-omarchy/branches/main/protection/enforce_admins","enabled":true},"required_linear_history":{"enabled":false},"allow_force_pushes":{"enabled":false},"allow_deletions":{"enabled":false},"block_creations":{"enabled":false},"required_conversation_resolution":{"enabled":false},"lock_branch":{"enabled":false},"allow_fork_syncing":{"enabled":false}}''')


def review(n=1, login='pastawithpesto', uid=23729105, state='APPROVED', head=HEAD):
    return {'id': n, 'user': {'login': login, 'id': uid}, 'state': state, 'commit_id': head, 'submitted_at': f'2026-10-11T06:{n:02}:00Z'}


def pr(number=1):
    repo = {'id': 42, 'full_name': 'pastawithpesto/dji-studio-omarchy'}
    return {'number': number, 'state': 'open', 'draft': False, 'merged': False,
            'user': {'login': 'revmnds', 'id': 278795669}, 'head': {'sha': HEAD, 'ref': 'task', 'repo': repo},
            'base': {'sha': BASE, 'ref': 'main', 'repo': repo}, 'changed_files': 1,
            'mergeable': True, 'mergeable_state': 'clean', 'merge_commit_sha': MERGE,
            'body': '<!-- work-claim ' + json.dumps({'owner': 'revmnds', 'task': 'fixed fixture', 'paths': [f'area{number}/**']}) + ' -->'}


class Fake(W.GitHub):
    def __init__(self, apply=False):
        super().__init__(apply)
        self.prs = {1: pr()}
        self.files = {1: [{'filename': 'area1/file', 'status': 'modified'}]}
        self.reviews = [review()]
        self.permission = {'permission': 'write', 'user': {'login': 'revmnds', 'id': 278795669, 'permissions': {'push': True}}}
        self.branch = {'name': 'main', 'protected': True, 'commit': {'sha': BASE}}
        self.protection = protection()
        self.comparison = {'base_commit': {'sha': BASE}, 'merge_base_commit': {'sha': BASE},
                           'status': 'ahead', 'ahead_by': 1, 'behind_by': 0, 'total_commits': 1}
        self.rules = []
        self.rulesets = []
        self.statuses = [{'context':'agent-review/verified','state':'success','id':8,
                         'creator':{'login':'pastawithpesto','id':23729105},
                         'target_url':'https://github.com/pastawithpesto/dji-studio-omarchy/pull/1#pullrequestreview-1'}]
        self.runs = [{'id': 70, 'name': 'unit', 'head_sha': HEAD, 'status': 'completed', 'conclusion': 'success', 'app': {'id': 15368}}]
        self.hook = None
        self.counts = {}
        self.merges = []

    def get(self, path):
        self.calls += 1
        u = urlsplit(path); name=u.path; page=int(parse_qs(u.query).get('page', ['1'])[0])
        self.counts[name] = self.counts.get(name, 0) + 1
        if self.hook:
            replacement = self.hook(name, self.counts[name], page)
            if replacement is not None: return copy.deepcopy(replacement)
        if name == '':
            data = {'full_name': 'pastawithpesto/dji-studio-omarchy', 'owner': {'login':'pastawithpesto','id':23729105}, 'archived':False, 'disabled':False, 'allow_merge_commit':True}
        elif name == '/pulls': data = list(self.prs.values()) if page == 1 else []
        elif name == '/collaborators/revmnds/permission': data = self.permission
        elif name == '/branches/main': data = self.branch
        elif name == '/branches/main/protection': data = self.protection
        elif name.startswith('/compare/'): data = self.comparison
        elif name == '/rules/branches/main': data = self.rules if page == 1 else []
        elif name == '/rulesets': data = self.rulesets if page == 1 else []
        elif name.startswith('/pulls/'):
            parts=name.split('/'); number=int(parts[2])
            data = self.reviews if name.endswith('/reviews') else self.files[number] if name.endswith('/files') else self.prs[number]
        elif name.startswith('/commits/'):
            commit=name.split('/')[2]
            if name.endswith('/status'):
                values=self.statuses if commit == HEAD else []
                data={'sha':commit,'state':'success' if values else 'pending','total_count':len(values),'statuses':values if page == 1 else []}
            else:
                values=self.runs if commit == HEAD else []
                data={'total_count':len(values),'check_runs':values if page == 1 else []}
        else: raise AssertionError('Unexpected endpoint ' + path)
        return copy.deepcopy(data)

    def merge(self, number, head):
        self.merges.append((number, head))
        return {'merged': True, 'sha': 'd' * 40}


class Policy(unittest.TestCase):
    def refused(self, api, expected=None):
        intents=[]
        try:
            result=W.evaluate(api, True, intents.append)
        except (W.Unavailable, KeyError, ValueError, TypeError):
            result=None
        self.assertEqual(api.merges, [])
        self.assertEqual(intents, [])
        if expected and result is not None:self.assertIn(expected,str(result))

    def test_eligible_dry_run_never_puts(self):
        api=Fake();result=W.evaluate(api)
        self.assertEqual((result['action'],result['head'],result['base']),('eligible-dry-run',HEAD,BASE))
        self.assertEqual(api.merges, [])

    def test_eligible_apply_has_expected_sha_and_intent_first(self):
        api=Fake(True);intents=[]
        result=W.evaluate(api, True, lambda event:(self.assertEqual(api.merges,[]),intents.append(event.copy())))
        self.assertEqual(api.merges, [(1,HEAD)]);self.assertEqual(result['action'],'merged')
        self.assertEqual(intents[0]['action'],'eligible-dry-run')

    def test_missing_activation_or_intent_never_merges(self):
        api=Fake();self.refused(api)
        api=Fake(True)
        with self.assertRaises(W.Unavailable):W.evaluate(api,True)
        self.assertEqual(api.merges,[])

    def test_unrelated_and_spoofed_author_and_draft(self):
        for key,value in [('login','other'),('id',23729105),('id',True)]:
            api=Fake(True);api.prs[1]['user'][key]=value;self.refused(api)
        api=Fake(True);api.prs[1]['draft']=True;self.refused(api)

    def test_no_approval_stale_and_wrong_owner(self):
        for reviews in [[],[review(head='e'*40)],[review(login='other')],[review(uid=9)],[review(state='DISMISSED')],[review(state='PENDING')]]:
            api=Fake(True);api.reviews=reviews;self.refused(api)

    def test_veto_survives_comment_and_stale_head(self):
        api=Fake(True);api.reviews=[review(),review(2,'bob',7,'CHANGES_REQUESTED',head='e'*40),review(3,'bob',7,'COMMENTED')]
        self.refused(api,'Outstanding changes requested')

    def test_veto_cleared_only_by_substantive_approval_or_dismissal(self):
        W.reviews_allow([review(),review(2,'bob',7,'CHANGES_REQUESTED'),review(3,'bob',7,'APPROVED')],HEAD)
        W.reviews_allow([review(),review(2,'bob',7,'DISMISSED')],HEAD)
        with self.assertRaises(W.Unavailable):W.reviews_allow([review(),review(2,'bob',7,'CHANGES_REQUESTED'),review(3,'bob',7,'DISMISSED')],HEAD)

    def test_write_permission_is_current_and_numeric(self):
        for perm,uid,push in [('read',278795669,False),('write',4,True),('write',278795669,False)]:
            api=Fake(True);api.permission['permission']=perm;api.permission['user']['id']=uid;api.permission['user']['permissions']['push']=push;self.refused(api)

    def test_target_and_mergeability_policy(self):
        for key,value in [('mergeable',False),('mergeable',None),('mergeable_state','blocked'),('mergeable_state','unstable')]:
            api=Fake(True);api.prs[1][key]=value;self.refused(api)
        api=Fake(True);api.prs[1]['base']['ref']='release';self.refused(api)
        api=Fake(True);api.prs[1]['base']['repo']['full_name']='other/repo';self.refused(api)
        api=Fake(True);api.branch['protected']=False;self.refused(api)
        api=Fake(True);api.rules=[{'type':'required_status_checks'}];self.refused(api)
        api=Fake(True);api.rulesets=[{'id':1,'enforcement':'disabled'}];self.refused(api)

    def test_failed_pending_neutral_skipped_and_missing_checks(self):
        for status,conclusion in [('completed','failure'),('in_progress',None),('completed','neutral'),('completed','skipped'),('completed','cancelled')]:
            api=Fake(True);api.runs[0].update(status=status,conclusion=conclusion);self.refused(api)
        api=Fake(True);api.runs=[];api.statuses=[];self.refused(api)
        api=Fake(True);api.statuses=[{'context':'legacy','state':'failure','id':8}];self.refused(api)

    def test_status_only_success_and_failing_test_merge(self):
        api=Fake();api.runs=[];api.statuses=[{'context':'agent-review/verified','state':'success','id':8,'creator':{'login':'pastawithpesto','id':23729105},'target_url':'https://github.com/pastawithpesto/dji-studio-omarchy/pull/1#pullrequestreview-1'}]
        self.assertEqual(W.evaluate(api)['action'],'eligible-dry-run')
        api=Fake(True)
        api.hook=lambda name,count,page: {'total_count':1,'check_runs':[dict(api.runs[0],head_sha=MERGE,conclusion='failure')]} if name.endswith('/check-runs') and MERGE in name else None
        self.refused(api)

    def test_wrong_check_head_and_duplicate_identity(self):
        api=Fake(True);api.runs[0]['head_sha']='e'*40;self.refused(api)
        api=Fake(True);api.runs.append(copy.deepcopy(api.runs[0]));self.refused(api)
        api=Fake(True);api.runs.append(dict(api.runs[0],id=71));self.refused(api)

    def test_complete_claims_conflicts_and_rename_coverage(self):
        api=Fake(True);api.prs[1]['body']='missing';self.refused(api)
        api=Fake(True);api.files[1][0]['previous_filename']='outside/file';self.refused(api)
        api=Fake(True);api.prs[2]=pr(2);api.files[2]=[{'filename':'area2/file','status':'modified'}]
        api.prs[2]['body']=api.prs[1]['body'];self.refused(api)

    def test_incomplete_count_and_duplicate_file(self):
        api=Fake(True);api.prs[1]['changed_files']=2;self.refused(api)
        api=Fake(True);api.prs[1]['changed_files']=2;api.files[1]*=2;self.refused(api)
        api=Fake(True);api.files[1][0]['status']='renamed';self.refused(api)

    def test_unterminated_page_and_api_error(self):
        api=Fake(True);api.hook=lambda name,count,page: [pr()] * 100 if name=='/pulls' else None
        self.refused(api)
        api=Fake(True)
        def error(name,count,page):
            if name=='/pulls/1/reviews':raise W.Unavailable('API unavailable')
        api.hook=error;self.refused(api)

    def test_counted_check_inventory_gap(self):
        api=Fake(True)
        api.hook=lambda name,count,page: {'total_count':2,'check_runs':api.runs} if name.endswith('/check-runs') and HEAD in name else None
        self.refused(api)

    def test_head_base_permission_review_check_and_claim_races(self):
        def mutate(kind,api,name,count):
            if kind in {'head','claim','membership'} and name=='/pulls' and count==3:
                if kind=='head':api.prs[1]['head']['sha']='e'*40
                elif kind=='claim':api.prs[1]['body']=api.prs[1]['body'].replace('fixed fixture','edited')
                else:api.prs={}
            if kind=='base' and name=='/branches/main' and count==2:api.branch['commit']['sha']='e'*40
            if kind=='permission' and name=='/collaborators/revmnds/permission' and count==2:api.permission['permission']='read'
            if kind=='review' and name=='/pulls/1/reviews' and count==2:api.reviews=[review(state='CHANGES_REQUESTED')]
            if kind=='check' and name.endswith('/check-runs') and HEAD in name and count==2:api.runs[0]['id']=71
            if kind=='lasthead' and name=='/pulls/1' and count==5:api.prs[1]['head']['sha']='e'*40
        for kind in ['head','claim','membership','base','permission','review','check','lasthead']:
            api=Fake(True);api.hook=lambda name,count,page,k=kind:mutate(k,api,name,count)
            self.refused(api)

    def test_normal_not_ready_pr_does_not_starve_next(self):
        api=Fake(True);api.prs[2]=pr(2);api.files[2]=[{'filename':'area2/file','status':'modified'}]
        api.hook=lambda name,count,page: [] if name=='/pulls/1/reviews' else None
        result=W.evaluate(api,True,lambda e:None)
        self.assertEqual(result['pr'],2);self.assertEqual(api.merges,[(2,HEAD)])

    def test_exact_protection_policy_with_observed_null_omission(self):
        for explicit in [False,True]:
            api=Fake()
            if explicit:api.protection['restrictions']=None
            result=W.evaluate(api)
            self.assertEqual(result['action'],'eligible-dry-run')
            self.assertEqual(api.counts['/branches/main/protection'],2)
            self.assertEqual(api.counts['/compare/'+BASE+'...'+HEAD],2)
            self.assertEqual(api.merges,[])

    def test_every_protection_leaf_change_missing_and_unknown_refuses(self):
        def leaves(value,path=()):
            if isinstance(value,dict):
                for k,v in value.items():yield from leaves(v,path+(k,))
            elif isinstance(value,list):
                for k,v in enumerate(value):yield from leaves(v,path+(k,))
            else:yield path,value
        def locate(value,path):
            for key in path[:-1]:value=value[key]
            return value,path[-1]
        for path,value in leaves(protection()):
            for action in ['change','delete']:
                with self.subTest(path=path,action=action):
                    api=Fake(True);obj,key=locate(api.protection,path)
                    if action=='delete':del obj[key]
                    else:obj[key]=(not value) if type(value) is bool else 1 if value is None or type(value) is int else 'unknown'
                    self.refused(api)
        for path in [(),('required_status_checks',),('required_pull_request_reviews',),('enforce_admins',),('required_status_checks','checks',0)]:
            api=Fake(True);obj=api.protection
            for key in path:obj=obj[key]
            obj['unknown_policy']=True;self.refused(api)
        for field in list(protection()):
            api=Fake(True);del api.protection[field];self.refused(api)
        for name in ['restrictions','bypass_pull_request_allowances']:
            api=Fake(True);api.protection[name]={'users':[{'login':'pastawithpesto'}]};self.refused(api)
        api=Fake(True);api.protection['required_pull_request_reviews']['required_approving_review_count']=False;self.refused(api)
        api=Fake(True);api.protection['required_status_checks']['checks'][0]['app_id']=-1;self.refused(api)

    def test_required_named_status_is_current_successful_owner_status(self):
        for changes in [{'context':'other'},{'state':'pending'},{'state':'error'},{'state':'failure'},
                        {'creator':{'login':'other','id':23729105}},
                        {'creator':{'login':'pastawithpesto','id':4}}, {'creator':None}]:
            api=Fake(True);api.statuses[0].update(changes);self.refused(api)
        api=Fake(True);api.statuses=[];api.runs[0]['name']='agent-review/verified';self.refused(api)
        api=Fake(True);api.hook=lambda name,count,page: {'sha':'e'*40,'state':'success','total_count':1,'statuses':api.statuses} if name.endswith('/status') and HEAD in name else None
        self.refused(api)
        api=Fake(True);api.hook=lambda name,count,page: {'sha':HEAD,'state':'success','total_count':2,'statuses':api.statuses} if name.endswith('/status') and HEAD in name else None
        self.refused(api)
        api=Fake(True);api.hook=lambda name,count,page: {'sha':'e'*40,'state':'success','total_count':1,'statuses':api.statuses} if name.endswith('/status') and HEAD in name and count==2 else None
        self.refused(api)

    def test_strict_up_to_date_ancestry_and_unknown_mergeability(self):
        for changes in [{'status':'behind'},{'status':'diverged'},{'behind_by':1},{'ahead_by':True},
                        {'total_commits':2},{'base_commit':{'sha':'e'*40}},
                        {'merge_base_commit':{'sha':'e'*40}}]:
            api=Fake(True);api.comparison.update(changes);self.refused(api)
        for key in Fake().comparison:
            api=Fake(True);del api.comparison[key];self.refused(api)
        for state in ['behind','unknown','dirty','has_hooks','blocked']:
            api=Fake(True);api.prs[1]['mergeable_state']=state;self.refused(api)
        api=Fake();api.comparison.update(status='identical',ahead_by=0,total_commits=0)
        self.assertEqual(W.evaluate(api)['action'],'eligible-dry-run')

    def test_protection_rules_ancestry_and_attestation_races(self):
        for kind in ['protection','rules','rulesets','ancestry','attestation','attestationcreator']:
            api=Fake(True)
            def mutate(name,count,page):
                if kind=='protection' and name=='/branches/main/protection' and count==2:api.protection['enforce_admins']['enabled']=False
                if kind=='rules' and name=='/rules/branches/main' and count==2:api.rules=[{'type':'required_signatures'}]
                if kind=='rulesets' and name=='/rulesets' and count==2:api.rulesets=[{'id':1,'enforcement':'active'}]
                if kind=='ancestry' and name.startswith('/compare/') and count==2:api.comparison.update(status='ahead',ahead_by=2,total_commits=2)
                if kind.startswith('attestation') and name.endswith('/status') and HEAD in name and count==3:
                    if kind=='attestation':api.statuses[0]['id']=9
                    else:api.statuses[0]['creator']['id']=9
            api.hook=mutate;self.refused(api)

    def test_protection_api_error_and_rules_incomplete_page(self):
        api=Fake(True)
        def error(name,count,page):
            if name=='/branches/main/protection':raise W.Unavailable('Protection GET denied',http_status=403)
        api.hook=error;self.refused(api)
        api=Fake(True);api.hook=lambda name,count,page: [{}]*100 if name=='/rules/branches/main' else None
        self.refused(api)
        api=Fake(True);api.hook=lambda name,count,page: [{}]*100 if name=='/rulesets' else None
        self.refused(api)


class Transport(unittest.TestCase):
    def response(self,status=200,body=None,extra=''):
        return types.SimpleNamespace(returncode=0 if status==200 else 1,stdout=f'HTTP/2.0 {status}\n{extra}\n'+json.dumps(body),stderr='TOKEN_MUST_NOT_APPEAR')

    def test_default_transport_refuses_put_and_other_mutations(self):
        with patch.object(W.subprocess,'run') as run:
            with self.assertRaises(W.Unavailable):W.GitHub().merge(1,HEAD)
            with self.assertRaises(W.Unavailable):W.GitHub(True).request('/issues/1',{'sha':HEAD,'merge_method':'merge'})
            run.assert_not_called()

    def test_expected_sha_put_argv_and_secret_privacy(self):
        response=self.response(body={'merged':True,'sha':'d'*40})
        with patch.object(W.subprocess,'run',return_value=response) as run,patch.dict(os.environ,{'GH_DEBUG':'api'}):
            api=W.GitHub(True);api.merge(7,HEAD)
            args=run.call_args.args[0];self.assertEqual(args[args.index('--method')+1],'PUT')
            self.assertEqual(args[-2:],['--input','-'])
            self.assertEqual(json.loads(run.call_args.kwargs['input']),{'sha':HEAD,'merge_method':'merge'})
            self.assertNotIn('GH_DEBUG',run.call_args.kwargs['env'])
            self.assertNotIn('TOKEN_MUST_NOT_APPEAR',json.dumps(api.records))
            self.assertNotIn('--admin',args)

    def test_error_redaction_rate_limit_timeout_and_budget(self):
        with patch.object(W.subprocess,'run',return_value=self.response(403,{},'Retry-After: 80\n')):
            with self.assertRaises(W.Unavailable) as e:W.GitHub().get('/pulls')
            self.assertEqual(e.exception.retry_after,80);self.assertFalse(e.exception.mutation)
            self.assertNotIn('TOKEN_MUST_NOT_APPEAR',str(e.exception))
        with patch.object(W.subprocess,'run',side_effect=subprocess.TimeoutExpired('mock',25)):
            with self.assertRaises(W.Unavailable):W.GitHub().get('/pulls')
        api=W.GitHub();api.calls=128
        with patch.object(W.subprocess,'run') as run:
            with self.assertRaises(W.Unavailable):api.get('/pulls')
            run.assert_not_called()


class Runtime(unittest.TestCase):
    def invoke(self,directory,apply=False,api=None,evaluate=None):
        argv=['worker','--once','--runtime',str(directory)]+(['--apply'] if apply else [])
        with patch.object(sys,'argv',argv),patch.object(W.signal,'signal'),patch.object(W,'GitHub',return_value=api or Fake(apply)),patch.object(W,'evaluate',side_effect=evaluate) if evaluate else contextlib.nullcontext(),contextlib.redirect_stdout(io.StringIO()),patch.object(W.random,'uniform',return_value=0):
            code=W.main()
        return code,json.loads((directory/'state.json').read_text()),json.loads((directory/'heartbeat.json').read_text())

    def test_once_is_dryrun_and_heartbeat_coherent(self):
        with tempfile.TemporaryDirectory() as d:
            code,state,h=self.invoke(Path(d))
            self.assertEqual(code,0);self.assertFalse(h['apply']);self.assertEqual(h['mode'],'once')
            self.assertEqual(h['pid'],os.getpid());self.assertEqual(h['process_start'],Path('/proc/self/stat').read_text().rsplit(')',1)[1].split()[19])
            self.assertIsNone(h['error'])

    def test_failure_backoff_survives_restart(self):
        with tempfile.TemporaryDirectory() as d:
            directory=Path(d)
            for count,wait in [(1,80),(2,80),(3,120)]:
                code,state,h=self.invoke(directory,evaluate=W.Unavailable('fixed outage',80))
                self.assertEqual((code,state['failure_count'],h['next_attempt_seconds']),(2,count,wait))
            code,state,h=self.invoke(directory)
            self.assertEqual((code,state['failure_count'],h['next_attempt_seconds']),(0,0,30))

    def test_nonobject_combined_http200_persists_retry_heartbeat_and_recovers(self):
        actual_get = W.GitHub.get
        for value in [None, [], [1], 'unexpected', 7, True]:
            with self.subTest(value=value),tempfile.TemporaryDirectory() as d:
                class Malformed(Fake):
                    def get(self,path):
                        if path.startswith('/commits/') and '/status?' in path:
                            return actual_get(self,path)
                        return super().get(path)
                api=Malformed()
                response=Transport().response(body=value)
                with patch.object(W.subprocess,'run',return_value=response):
                    code,state,h=self.invoke(Path(d),api=api)
                self.assertEqual(code,2);self.assertEqual(state['failure_count'],1)
                self.assertEqual(h['error'],'Combined status response must be an object')
                self.assertEqual(h['next_attempt_seconds'],30);self.assertIsNone(h['result'])
                self.assertNotIn('merge_intent',state);self.assertEqual(api.merges,[])
                self.assertFalse((Path(d)/'events.jsonl').exists())
                self.assertEqual(api.records[-1]['method'],'GET')
                code,state,h=self.invoke(Path(d))
                self.assertEqual((code,state['failure_count']),(0,0))
                self.assertIsNone(h['error']);self.assertEqual(h['result']['action'],'eligible-dry-run')

    def test_nonobject_merge_http200_intent_retry_restart_and_no_reissue(self):
        actual_merge = W.GitHub.merge
        for value in [None, [], [1], 'unexpected', 7, True]:
            with self.subTest(value=value),tempfile.TemporaryDirectory() as d:
                class Malformed(Fake):
                    def merge(self,number,head):
                        # Use the real constrained PUT transport under a subprocess mock.
                        self.merges.append((number,head))
                        return actual_merge(self,number,head)
                api=Malformed(True);directory=Path(d)
                with patch.object(W.subprocess,'run',return_value=Transport().response(body=value)) as run:
                    code,state,h=self.invoke(directory,True,api)
                self.assertEqual(code,2);self.assertEqual(api.merges,[(1,HEAD)])
                self.assertEqual(run.call_count,1)
                self.assertEqual(json.loads(run.call_args.kwargs['input']),{'sha':HEAD,'merge_method':'merge'})
                self.assertEqual(state['merge_intent']['head'],HEAD)
                self.assertEqual(h['merge_intent'],state['merge_intent'])
                self.assertEqual((state['failure_count'],h['next_attempt_seconds']),(1,30))
                self.assertEqual(h['error'],'Merge receipt must be an object; outcome uncertain')
                self.assertFalse((directory/'events.jsonl').exists())
                # Restart observes an open PR and must neither clear intent nor retry PUT.
                restarted=Fake(True);code,state,h=self.invoke(directory,True,restarted)
                self.assertEqual((code,state['failure_count'],h['next_attempt_seconds']),(2,2,60))
                self.assertEqual(restarted.counts,{'/pulls/1':1});self.assertEqual(restarted.merges,[])
                self.assertEqual(state['merge_intent']['head'],HEAD)
                restarted.prs[1].update(state='closed',merged=True,merge_commit_sha='d'*40)
                code,state,h=self.invoke(directory,True,restarted)
                self.assertEqual(code,0);self.assertNotIn('merge_intent',state)
                self.assertEqual(h['result']['action'],'reconciled-merge');self.assertEqual(restarted.merges,[])
                self.assertEqual(state['failure_count'],0)

    def test_malformed_object_merge_retains_intent(self):
        for value in [{},{'merged':True,'sha':None},{'merged':False,'sha':'d'*40}]:
            with self.subTest(value=value),tempfile.TemporaryDirectory() as d:
                class Malformed(Fake):
                    def merge(self,number,head):
                        self.merges.append((number,head));return value
                api=Malformed(True);code,state,h=self.invoke(Path(d),True,api)
                self.assertEqual(code,2);self.assertEqual(api.merges,[(1,HEAD)])
                self.assertEqual(h['error'],'Merge outcome uncertain');self.assertIn('merge_intent',state)

    def test_programming_attribute_error_is_not_blanket_swallowed(self):
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(AttributeError):
                self.invoke(Path(d),evaluate=AttributeError('deliberate programming defect'))

    def test_continuous_uncertain_receipt_heartbeats_no_second_put(self):
        actual_merge=W.GitHub.merge
        class Malformed(Fake):
            def merge(self,number,head):
                self.merges.append((number,head));return actual_merge(self,number,head)
        first,second,third=Malformed(True),Fake(True),Fake(True)
        third.prs[1].update(state='closed',merged=True,merge_commit_sha='d'*40)
        handlers={};now=[1000];observations=[]
        def register(signum,handler):handlers[signum]=handler
        def sleep(seconds):now[0]+=seconds
        def finish(name,count,page):handlers[W.signal.SIGTERM](None,None)
        third.hook=finish
        apis=iter([first,second,third])
        def next_api(apply):observations.append(now[0]);return next(apis)
        with tempfile.TemporaryDirectory() as d:
            directory=Path(d);out=io.StringIO()
            with patch.object(sys,'argv',['worker','--apply','--runtime',d]),patch.object(W,'GitHub',side_effect=next_api),patch.object(W.signal,'signal',side_effect=register),patch.object(W.time,'time',side_effect=lambda:now[0]),patch.object(W.time,'sleep',side_effect=sleep),patch.object(W.random,'uniform',return_value=0),patch.object(W.subprocess,'run',return_value=Transport().response(body=None)) as run,contextlib.redirect_stdout(out):
                code=W.main()
            beats=[json.loads(line) for line in out.getvalue().splitlines()]
            self.assertEqual(code,0);self.assertEqual(observations,[1000,1030,1090])
            self.assertEqual([h['attempts'] for h in beats],[1,2,3])
            self.assertEqual([h['failure_count'] for h in beats],[1,2,0])
            self.assertEqual([h['next_attempt_seconds'] for h in beats],[30,60,30])
            self.assertTrue(all(h['mode']=='continuous' and h['apply'] is True for h in beats))
            self.assertTrue(all(h['merge_intent'] for h in beats[:2]));self.assertIsNone(beats[2]['merge_intent'])
            self.assertEqual(beats[2]['result']['action'],'reconciled-merge')
            self.assertEqual(run.call_count,1);self.assertEqual(first.merges,[(1,HEAD)])
            self.assertEqual(second.merges,[]);self.assertEqual(third.merges,[])
            self.assertEqual(second.counts,{'/pulls/1':1});self.assertEqual(third.counts,{'/pulls/1':1})
            self.assertTrue((directory/'stopped.json').exists())

    def test_uncertain_put_intent_survives_get403_and_no_remerge(self):
        with tempfile.TemporaryDirectory() as d:
            directory=Path(d)
            def uncertain(api,apply,intent):
                intent({'pr':1,'head':HEAD});raise W.Unavailable('uncertain PUT')
            code,state,h=self.invoke(directory,True,evaluate=uncertain)
            self.assertEqual(state['merge_intent']['head'],HEAD)
            api=Fake(True)
            def forbid(name,count,page):raise W.Unavailable('GET forbidden',http_status=403)
            api.hook=forbid
            code,state,h=self.invoke(directory,True,api)
            self.assertIn('merge_intent',state);self.assertEqual(api.merges,[])
            api=Fake(True);code,state,h=self.invoke(directory,True,api)
            self.assertIn('merge_intent',state);self.assertEqual(api.merges,[])
            api.prs[1].update(state='closed',merged=True,merge_commit_sha='d'*40)
            code,state,h=self.invoke(directory,True,api)
            self.assertEqual(code,0);self.assertNotIn('merge_intent',state);self.assertEqual(h['result']['action'],'reconciled-merge')

    def test_definitive_put_rejection_removes_only_current_intent(self):
        with tempfile.TemporaryDirectory() as d:
            def rejected(api,apply,intent):
                intent({'pr':1,'head':HEAD});raise W.Unavailable('rejected',http_status=409,mutation=True)
            code,state,h=self.invoke(Path(d),True,evaluate=rejected)
            self.assertEqual(code,2);self.assertNotIn('merge_intent',state)

    def test_same_runtime_singleton_and_persisted_continuous_cooldown(self):
        with tempfile.TemporaryDirectory() as d:
            directory=Path(d)
            with (directory/'lock').open('a+') as lock:
                fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
                with self.assertRaises(SystemExit),contextlib.redirect_stderr(io.StringIO()):self.invoke(directory)
            W.atomic(directory/'state.json',{'version':1,'repo':W.REPO,'failure_count':2,'next_attempt_epoch':1060})
            now=[1000];seen=[];handlers={}
            def register(signum,handler):handlers[signum]=handler
            def sleep(seconds):now[0]+=seconds
            def evaluate(api,apply,intent):
                seen.append(now[0]);handlers[W.signal.SIGTERM](None,None)
                return {'action':'no-candidate'}
            with patch.object(sys,'argv',['worker','--runtime',str(directory)]),patch.object(W.signal,'signal',side_effect=register),patch.object(W.time,'time',side_effect=lambda:now[0]),patch.object(W.time,'sleep',side_effect=sleep),patch.object(W,'evaluate',side_effect=evaluate),patch.object(W,'GitHub',return_value=Fake()),contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(W.main(),0)
            self.assertEqual(seen,[1060])


if __name__=='__main__':unittest.main(verbosity=2)
