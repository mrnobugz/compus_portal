import json
import time
from pathlib import Path

_LOG_PATH = Path(__file__).resolve().parent.parent.parent / 'debug-32521d.log'
_SESSION_ID = '32521d'
_AUTH_PATHS = ('/api/token/', '/api/users/me/', '/api/auth/register/')


def _agent_log(hypothesis_id, location, message, data=None, run_id='pre-fix'):
    # #region agent log
    entry = {
        'sessionId': _SESSION_ID,
        'hypothesisId': hypothesis_id,
        'location': location,
        'message': message,
        'data': data or {},
        'timestamp': int(time.time() * 1000),
        'runId': run_id,
    }
    try:
        with open(_LOG_PATH, 'a', encoding='utf-8') as f:
            f.write(json.dumps(entry) + '\n')
    except OSError:
        pass
    # #endregion


class DebugAuthMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if request.path in _AUTH_PATHS:
            _agent_log(
                'A',
                'debug_middleware.py:request',
                'auth request received',
                {
                    'path': request.path,
                    'method': request.method,
                    'host': request.get_host(),
                    'remote_addr': request.META.get('REMOTE_ADDR'),
                },
            )
        response = self.get_response(request)
        if request.path in _AUTH_PATHS:
            _agent_log(
                'B',
                'debug_middleware.py:response',
                'auth response sent',
                {'path': request.path, 'status': response.status_code},
            )
        return response
