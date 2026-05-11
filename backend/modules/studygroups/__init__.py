from flask import Blueprint

studygroups_bp = Blueprint('studygroups', __name__, url_prefix='/api/studygroups')

from . import routes
