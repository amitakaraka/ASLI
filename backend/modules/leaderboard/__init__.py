from flask import Blueprint

leaderboard_bp = Blueprint('leaderboard', __name__, url_prefix='/api/leaderboard')

from . import routes
