#!/usr/bin/env python3
"""
Alternative Google Drive backup using Google Drive API
When gdrive CLI has port conflicts
"""

import os
import zipfile
import shutil
from pathlib import Path
from datetime import datetime

def create_backup_archive(source_dir, output_dir="backups"):
    """Create compressed backup archives for manual upload"""
    if not os.path.exists(source_dir):
        print(f"Directory {source_dir} not found")
        return None
    
    # Create backup directory
    os.makedirs(output_dir, exist_ok=True)
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    archive_name = f"{output_dir}/{os.path.basename(source_dir)}_{timestamp}.zip"
    
    print(f"Creating archive: {archive_name}")
    
    with zipfile.ZipFile(archive_name, 'w', zipfile.ZIP_DEFLATED) as zipf:
        source_path = Path(source_dir)
        for file_path in source_path.rglob('*'):
            if file_path.is_file():
                # Skip temporary files and logs
                if not any(skip in file_path.name for skip in ['.tmp', '.log', 'core.']):
                    arcname = file_path.relative_to(source_path.parent)
                    zipf.write(file_path, arcname)
    
    size_mb = os.path.getsize(archive_name) / (1024 * 1024)
    print(f"Archive created: {archive_name} ({size_mb:.1f} MB)")
    return archive_name

def backup_large_directories():
    """Create backup archives of large directories"""
    print("=== Creating backup archives ===")
    
    large_dirs = [
        'simulation_results_90cases',
        'simulation_results_gnn', 
        'odor_simulation_results',
        'laminar_simulation'
    ]
    
    created_archives = []
    
    for dirname in large_dirs:
        if os.path.exists(dirname):
            size_gb = sum(
                os.path.getsize(os.path.join(dirpath, filename))
                for dirpath, dirnames, filenames in os.walk(dirname)
                for filename in filenames
            ) / (1024**3)
            
            if size_gb > 0.1:  # Only backup directories > 100MB
                print(f"\nBacking up {dirname} ({size_gb:.1f} GB)...")
                archive = create_backup_archive(dirname)
                if archive:
                    created_archives.append((dirname, archive))
    
    if created_archives:
        print("\n=== Backup Summary ===")
        print("Created the following backup archives:")
        total_size = 0
        for original_dir, archive_path in created_archives:
            size_mb = os.path.getsize(archive_path) / (1024 * 1024)
            total_size += size_mb
            print(f"  {archive_path} ({size_mb:.1f} MB)")
        
        print(f"\nTotal backup size: {total_size:.1f} MB")
        print("\n=== Manual Upload Instructions ===")
        print("1. Go to https://drive.google.com")
        print("2. Create a folder named 'OpenFOAM_Results'")
        print("3. Upload all .zip files from the 'backups' folder")
        print("4. After successful upload, run the cleanup:")
        print("   python3 gdrive_alternative.py --cleanup")
        
        return created_archives
    else:
        print("No large directories found to backup")
        return []

def cleanup_after_upload(archives_info):
    """Remove original directories after successful manual upload"""
    print("\n=== Cleanup after upload ===")
    confirm = input("Have you successfully uploaded all backup files to Google Drive? (yes/no): ")
    
    if confirm.lower() in ['yes', 'y']:
        for original_dir, archive_path in archives_info:
            if os.path.exists(original_dir):
                shutil.rmtree(original_dir)
                print(f"✅ Removed {original_dir}")
            
            if os.path.exists(archive_path):
                os.remove(archive_path)
                print(f"✅ Removed {archive_path}")
        
        # Remove backup directory if empty
        if os.path.exists("backups") and not os.listdir("backups"):
            os.rmdir("backups")
            print("✅ Removed empty backups directory")
        
        print("✅ Cleanup completed!")
    else:
        print("❌ Cleanup cancelled. Original files preserved.")

def get_disk_usage():
    """Get current disk usage"""
    import subprocess
    result = subprocess.run(['df', '.'], capture_output=True, text=True)
    lines = result.stdout.strip().split('\n')
    if len(lines) > 1:
        fields = lines[1].split()
        total_gb = int(fields[1]) / (1024 * 1024)
        used_gb = int(fields[2]) / (1024 * 1024)
        available_gb = int(fields[3]) / (1024 * 1024)
        percent_used = (used_gb / total_gb) * 100
        
        print(f"💾 Disk usage: {used_gb:.1f}/{total_gb:.1f} GB ({percent_used:.1f}%)")
        print(f"💾 Free space: {available_gb:.1f} GB")
        
        return available_gb

if __name__ == '__main__':
    import sys
    
    if '--cleanup' in sys.argv:
        # Load archive info from previous backup
        archives_file = 'backups/archive_info.txt'
        if os.path.exists(archives_file):
            with open(archives_file, 'r') as f:
                archives_info = []
                for line in f:
                    parts = line.strip().split('|')
                    if len(parts) == 2:
                        archives_info.append((parts[0], parts[1]))
            cleanup_after_upload(archives_info)
        else:
            print("No archive info found. Cannot perform cleanup.")
    else:
        print("=== Alternative Google Drive Backup ===")
        available_gb = get_disk_usage()
        
        if available_gb < 5.0:
            print(f"⚠️  Low disk space ({available_gb:.1f} GB)")
            archives_info = backup_large_directories()
            
            # Save archive info for later cleanup
            if archives_info:
                os.makedirs('backups', exist_ok=True)
                with open('backups/archive_info.txt', 'w') as f:
                    for original_dir, archive_path in archives_info:
                        f.write(f"{original_dir}|{archive_path}\n")
        else:
            print(f"✅ Sufficient disk space ({available_gb:.1f} GB)")