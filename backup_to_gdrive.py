#!/usr/bin/env python3
"""
Google Drive backup script for OpenFOAM simulation results
Automatically uploads large simulation results to Google Drive and cleans up local files
"""

import os
import sys
import shutil
import subprocess
import zipfile
import time
from pathlib import Path
from datetime import datetime
import argparse

def check_disk_space():
    """Check available disk space in GB"""
    statvfs = os.statvfs('.')
    available_gb = (statvfs.f_frsize * statvfs.f_bavail) / (1024**3)
    return available_gb

def get_directory_size(path):
    """Get directory size in GB"""
    total = 0
    for dirpath, dirnames, filenames in os.walk(path):
        for f in filenames:
            fp = os.path.join(dirpath, f)
            if os.path.exists(fp):
                total += os.path.getsize(fp)
    return total / (1024**3)

def create_archive(source_dir, archive_name):
    """Create compressed archive of simulation results"""
    print(f"Creating archive {archive_name} from {source_dir}...")
    
    with zipfile.ZipFile(archive_name, 'w', zipfile.ZIP_DEFLATED) as zipf:
        source_path = Path(source_dir)
        for file_path in source_path.rglob('*'):
            if file_path.is_file():
                # Skip temporary files and logs
                if not any(skip in file_path.name for skip in ['.tmp', '.log', 'core.']):
                    arcname = file_path.relative_to(source_path.parent)
                    zipf.write(file_path, arcname)
    
    print(f"Archive created: {archive_name} ({os.path.getsize(archive_name)/(1024**2):.1f} MB)")
    return archive_name

def install_gdrive_cli():
    """Install Google Drive CLI tool if not present"""
    try:
        subprocess.run(['gdrive', 'version'], check=True, capture_output=True)
        print("Google Drive CLI already installed")
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("Installing Google Drive CLI...")
        try:
            # Install via Homebrew on macOS
            subprocess.run(['brew', 'install', 'gdrive'], check=True)
            return True
        except subprocess.CalledProcessError:
            print("Failed to install gdrive. Please install manually:")
            print("1. Install Homebrew: /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"")
            print("2. Install gdrive: brew install gdrive")
            print("3. Authenticate: gdrive about")
            return False

def authenticate_gdrive():
    """Authenticate with Google Drive"""
    try:
        result = subprocess.run(['gdrive', 'about'], check=True, capture_output=True, text=True)
        print("Google Drive authentication successful")
        return True
    except subprocess.CalledProcessError:
        print("Please authenticate with Google Drive:")
        print("Run: gdrive about")
        print("Follow the authentication prompts")
        return False

def upload_to_gdrive(file_path, folder_name="OpenFOAM_Results"):
    """Upload file to Google Drive"""
    try:
        # Create or find the folder
        print(f"Uploading {file_path} to Google Drive...")
        
        # Try to find existing folder
        find_result = subprocess.run(
            ['gdrive', 'list', '--query', f"name='{folder_name}' and mimeType='application/vnd.google-apps.folder'"],
            capture_output=True, text=True, check=True
        )
        
        if folder_name in find_result.stdout:
            # Extract folder ID
            lines = find_result.stdout.strip().split('\n')
            for line in lines[1:]:  # Skip header
                if folder_name in line:
                    folder_id = line.split()[0]
                    break
        else:
            # Create new folder
            create_result = subprocess.run(
                ['gdrive', 'mkdir', folder_name],
                capture_output=True, text=True, check=True
            )
            folder_id = create_result.stdout.strip().split()[-1]
            print(f"Created folder {folder_name} with ID: {folder_id}")
        
        # Upload file to the folder
        upload_result = subprocess.run(
            ['gdrive', 'upload', '--parent', folder_id, file_path],
            capture_output=True, text=True, check=True
        )
        
        print(f"Successfully uploaded {file_path} to Google Drive")
        return True
        
    except subprocess.CalledProcessError as e:
        print(f"Failed to upload to Google Drive: {e}")
        print(f"stdout: {e.stdout}")
        print(f"stderr: {e.stderr}")
        return False

def cleanup_local_files(paths_to_remove):
    """Remove local files after successful upload"""
    for path in paths_to_remove:
        if os.path.exists(path):
            if os.path.isdir(path):
                shutil.rmtree(path)
                print(f"Removed directory: {path}")
            else:
                os.remove(path)
                print(f"Removed file: {path}")

def backup_simulation_results(dry_run=False, threshold_gb=5.0):
    """Main backup function"""
    print("=== OpenFOAM Simulation Results Backup ===")
    print(f"Available disk space: {check_disk_space():.1f} GB")
    
    # Find large simulation result directories
    large_dirs = []
    backup_candidates = [
        'simulation_results_90cases',
        'simulation_results_gnn', 
        'odor_simulation_results',
        'laminar_simulation',
        'debrisCase'
    ]
    
    for dirname in backup_candidates:
        if os.path.exists(dirname):
            size_gb = get_directory_size(dirname)
            if size_gb > 0.1:  # Only consider directories > 100MB
                large_dirs.append((dirname, size_gb))
                print(f"Found: {dirname} ({size_gb:.1f} GB)")
    
    if not large_dirs:
        print("No large simulation directories found")
        return
    
    # Sort by size (largest first)
    large_dirs.sort(key=lambda x: x[1], reverse=True)
    
    if dry_run:
        print("\n=== DRY RUN - No actual changes will be made ===")
        total_size = sum(size for _, size in large_dirs)
        print(f"Total size to backup: {total_size:.1f} GB")
        return
    
    # Install and authenticate Google Drive CLI
    if not install_gdrive_cli():
        return
    
    if not authenticate_gdrive():
        return
    
    # Backup each directory
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    uploaded_files = []
    
    for dirname, size_gb in large_dirs:
        if check_disk_space() < threshold_gb:
            print(f"Low disk space, backing up {dirname}...")
            
            archive_name = f"{dirname}_{timestamp}.zip"
            
            try:
                # Create archive
                create_archive(dirname, archive_name)
                
                # Upload to Google Drive
                if upload_to_gdrive(archive_name):
                    uploaded_files.append((dirname, archive_name))
                    print(f"Successfully backed up {dirname}")
                else:
                    print(f"Failed to backup {dirname}")
                    
            except Exception as e:
                print(f"Error backing up {dirname}: {e}")
    
    # Clean up local files after successful uploads
    if uploaded_files:
        print("\n=== Cleaning up local files ===")
        for dirname, archive_name in uploaded_files:
            cleanup_local_files([dirname, archive_name])
        
        print(f"Freed up disk space. Available: {check_disk_space():.1f} GB")

def main():
    parser = argparse.ArgumentParser(description='Backup OpenFOAM simulation results to Google Drive')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be backed up without making changes')
    parser.add_argument('--threshold', type=float, default=5.0, help='Disk space threshold in GB (default: 5.0)')
    
    args = parser.parse_args()
    
    backup_simulation_results(dry_run=args.dry_run, threshold_gb=args.threshold)

if __name__ == '__main__':
    main()