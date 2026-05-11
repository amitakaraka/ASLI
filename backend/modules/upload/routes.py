"""
Upload Routes — Image & File Uploads
Supports single/multiple uploads with configurable storage
"""
import os
import uuid
import time
from flask import Blueprint, request, jsonify
from werkzeug.utils import secure_filename
from modules.auth.jwt_utils import admin_required, token_required

upload_bp = Blueprint('upload', __name__, url_prefix='/api/upload')

# Allowed file extensions
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'heic', 'heif'}
MAX_FILE_SIZE = 16 * 1024 * 1024  # 16MB
SIGNATURES_BY_EXTENSION = {
    'png': (b'\x89PNG\r\n\x1a\n',),
    'jpg': (b'\xff\xd8\xff',),
    'jpeg': (b'\xff\xd8\xff',),
    'gif': (b'GIF87a', b'GIF89a'),
    'webp': (b'RIFF',),
    'heic': (b'ftypheic', b'ftypheix', b'ftyphevc', b'ftyphevx', b'ftypmif1', b'ftypmsf1'),
    'heif': (b'ftypheic', b'ftypheix', b'ftyphevc', b'ftyphevx', b'ftypmif1', b'ftypmsf1'),
}


def allowed_file(filename):
    """Check if file extension is allowed"""
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


def file_extension(filename):
    return filename.rsplit('.', 1)[1].lower() if '.' in filename else ''


def has_valid_image_signature(file_bytes, extension):
    """Validate basic image magic bytes so text/scripts cannot masquerade as images."""
    if not file_bytes:
        return False

    signatures = SIGNATURES_BY_EXTENSION.get(extension)
    if not signatures:
        return False

    if extension == 'webp':
        return (
            len(file_bytes) >= 12
            and file_bytes.startswith(b'RIFF')
            and file_bytes[8:12] == b'WEBP'
        )

    if extension in {'heic', 'heif'}:
        return len(file_bytes) >= 12 and file_bytes[4:12] in signatures

    return any(file_bytes.startswith(signature) for signature in signatures)


def has_any_valid_image_signature(file_bytes):
    return any(
        has_valid_image_signature(file_bytes, extension)
        for extension in ALLOWED_EXTENSIONS
    )


def uploaded_file_size(file):
    file.seek(0, 2)
    size = file.tell()
    file.seek(0)
    return size


def uploaded_file_has_valid_signature(file, extension):
    head = file.read(32)
    file.seek(0)
    return has_valid_image_signature(head, extension)


def get_upload_folder():
    """Get or create upload folder"""
    upload_folder = os.path.join(
        os.path.dirname(os.path.dirname(os.path.dirname(__file__))),
        'uploads'
    )
    os.makedirs(upload_folder, exist_ok=True)
    return upload_folder


def generate_filename(original_filename):
    """Generate unique filename preserving extension"""
    ext = original_filename.rsplit('.', 1)[1].lower() if '.' in original_filename else 'jpg'
    unique_id = uuid.uuid4().hex[:12]
    timestamp = int(time.time())
    return f"{timestamp}_{unique_id}.{ext}"


@upload_bp.route('/image', methods=['POST'])
@token_required
def upload_single_image(user_id):
    """
    Upload a single image file
    Returns: { success: bool, url: string, error?: string }
    """
    # Check if file is in request
    upload_file_key = 'file' if 'file' in request.files else 'image'
    if upload_file_key not in request.files:
        # Also check for base64 encoded image
        data = request.get_json(silent=True) or {}
        if 'image' in data:
            try:
                import base64
                image_data = data['image']
                if ',' in image_data:
                    image_data = image_data.split(',')[1]
                file_bytes = base64.b64decode(image_data)
                if len(file_bytes) > MAX_FILE_SIZE:
                    return jsonify({'success': False, 'error': f'File too large. Max: {MAX_FILE_SIZE // (1024*1024)}MB'}), 400
                if not has_any_valid_image_signature(file_bytes[:32]):
                    return jsonify({'success': False, 'error': 'Invalid image content'}), 400
                
                filename = generate_filename('image.jpg')
                filepath = os.path.join(get_upload_folder(), filename)
                
                with open(filepath, 'wb') as f:
                    f.write(file_bytes)
                
                url = f"/uploads/{filename}"
                return jsonify({
                    'success': True,
                    'url': url,
                    'filename': filename
                })
            except Exception as e:
                return jsonify({'success': False, 'error': f'Base64 decode error: {str(e)}'}), 400
        
        return jsonify({'success': False, 'error': 'No file provided'}), 400

    file = request.files[upload_file_key]
    
    # Check filename
    if file.filename == '':
        return jsonify({'success': False, 'error': 'No file selected'}), 400
    
    # Check file type
    extension = file_extension(file.filename)
    if not allowed_file(file.filename):
        return jsonify({'success': False, 'error': f'File type not allowed. Allowed: {", ".join(ALLOWED_EXTENSIONS)}'}), 400
    
    # Check file size
    size = uploaded_file_size(file)
    if size > MAX_FILE_SIZE:
        return jsonify({'success': False, 'error': f'File too large. Max: {MAX_FILE_SIZE // (1024*1024)}MB'}), 400
    if not uploaded_file_has_valid_signature(file, extension):
        return jsonify({'success': False, 'error': 'Invalid image content'}), 400
    
    # Save file
    try:
        filename = generate_filename(secure_filename(file.filename) if file.filename else 'image.jpg')
        filepath = os.path.join(get_upload_folder(), filename)
        file.save(filepath)
        
        url = f"/uploads/{filename}"
        return jsonify({
            'success': True,
            'url': url,
            'filename': filename,
            'size': size
        })
    except Exception as e:
        return jsonify({'success': False, 'error': f'Upload failed: {str(e)}'}), 500


@upload_bp.route('/images', methods=['POST'])
@token_required
def upload_multiple_images(user_id):
    """
    Upload multiple image files
    Returns: { success: bool, urls: string[], errors?: string[] }
    """
    if 'files' not in request.files:
        return jsonify({'success': False, 'error': 'No files provided'}), 400

    files = request.files.getlist('files')
    
    if not files or all(f.filename == '' for f in files):
        return jsonify({'success': False, 'error': 'No files selected'}), 400
    
    urls = []
    errors = []
    
    for file in files:
        if file.filename == '':
            continue
        
        extension = file_extension(file.filename)
        if not allowed_file(file.filename):
            errors.append(f"{file.filename}: unsupported format")
            continue
        
        # Check size
        size = uploaded_file_size(file)
        if size > MAX_FILE_SIZE:
            errors.append(f"{file.filename}: file too large")
            continue
        if not uploaded_file_has_valid_signature(file, extension):
            errors.append(f"{file.filename}: invalid image content")
            continue
        
        try:
            filename = generate_filename(secure_filename(file.filename) if file.filename else 'image.jpg')
            filepath = os.path.join(get_upload_folder(), filename)
            file.save(filepath)
            urls.append(f"/uploads/{filename}")
        except Exception as e:
            errors.append(f"{file.filename}: {str(e)}")
    
    if not urls:
        return jsonify({'success': False, 'error': 'All uploads failed', 'errors': errors}), 400
    
    return jsonify({
        'success': True,
        'urls': urls,
        'count': len(urls),
        'errors': errors if errors else None
    })


@upload_bp.route('/<filename>', methods=['GET'])
def get_uploaded_file(filename):
    """Serve uploaded file"""
    from flask import send_from_directory
    return send_from_directory(get_upload_folder(), filename)


@upload_bp.route('/list', methods=['GET'])
@admin_required
def list_uploads(user_id):
    """List all uploaded files (for admin/debug)"""
    upload_folder = get_upload_folder()
    files = []
    total_size = 0
    
    for f in os.listdir(upload_folder):
        filepath = os.path.join(upload_folder, f)
        if os.path.isfile(filepath):
            size = os.path.getsize(filepath)
            total_size += size
            files.append({
                'filename': f,
                'url': f"/uploads/{f}",
                'size': size,
                'size_human': f"{size / 1024:.1f} KB"
            })
    
    return jsonify({
        'success': True,
        'count': len(files),
        'total_size': total_size,
        'total_size_human': f"{total_size / (1024*1024):.2f} MB",
        'files': files
    })


@upload_bp.route('/<filename>', methods=['DELETE'])
@admin_required
def delete_upload(user_id, filename):
    """Delete an uploaded file"""
    # Security: only allow deletion of files in upload folder
    filename = secure_filename(filename)
    filepath = os.path.join(get_upload_folder(), filename)
    
    if not os.path.exists(filepath):
        return jsonify({'success': False, 'error': 'File not found'}), 404
    
    try:
        os.remove(filepath)
        return jsonify({'success': True, 'message': f'{filename} deleted'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500
