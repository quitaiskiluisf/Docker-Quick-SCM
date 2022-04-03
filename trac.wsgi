import os

os.environ['TRAC_ENV_PARENT_DIR'] = '/var/www/repos/trac-repos'
os.environ['PYTHON_EGG_CACHE'] = '/tmp/trac/scm/eggs'

import trac.web.main
application = trac.web.main.dispatch_request

