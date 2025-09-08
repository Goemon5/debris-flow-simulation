#!/usr/bin/env python3
"""
Storage management utilities for OpenFOAM simulations
Monitors disk usage and automatically manages storage
"""

import os
import subprocess
import shutil
import time
from pathlib import Path
import psutil

class StorageManager:
    def __init__(self, min_free_gb=5.0, cleanup_threshold_gb=2.0):
        self.min_free_gb = min_free_gb
        self.cleanup_threshold_gb = cleanup_threshold_gb
        
    def get_disk_usage(self):
        """Get disk usage statistics"""
        usage = psutil.disk_usage('.')
        return {
            'total_gb': usage.total / (1024**3),
            'used_gb': usage.used / (1024**3),
            'free_gb': usage.free / (1024**3),
            'percent_used': (usage.used / usage.total) * 100
        }
    
    def get_directory_size_gb(self, path):
        """Get directory size in GB"""
        if not os.path.exists(path):
            return 0
        
        total = 0
        try:
            for dirpath, dirnames, filenames in os.walk(path):
                for f in filenames:
                    fp = os.path.join(dirpath, f)
                    if os.path.exists(fp):
                        total += os.path.getsize(fp)
        except (OSError, IOError):
            pass
        return total / (1024**3)
    
    def find_large_directories(self, min_size_gb=0.5):
        """Find directories larger than min_size_gb"""
        large_dirs = []
        
        # Common OpenFOAM result directories
        candidates = [
            'simulation_results_90cases',
            'simulation_results_gnn', 
            'odor_simulation_results',
            'laminar_simulation',
            'debrisCase',
            'logs_90cases'
        ]
        
        # Also check for pattern directories
        for item in os.listdir('.'):
            if os.path.isdir(item):
                if any(pattern in item.lower() for pattern in ['pattern', 'case', 'result', 'simulation']):
                    if item not in candidates:
                        candidates.append(item)
        
        for dirname in candidates:
            if os.path.exists(dirname):
                size_gb = self.get_directory_size_gb(dirname)
                if size_gb >= min_size_gb:
                    large_dirs.append({
                        'path': dirname,
                        'size_gb': size_gb,
                        'modified': os.path.getmtime(dirname)
                    })
        
        return sorted(large_dirs, key=lambda x: x['size_gb'], reverse=True)
    
    def cleanup_temporary_files(self):
        """Clean up temporary files and logs"""
        cleanup_patterns = [
            '*.tmp',
            '*.log',
            'core.*',
            '*.bak',
            '__pycache__',
            '.DS_Store'
        ]
        
        freed_space = 0
        for pattern in cleanup_patterns:
            for file_path in Path('.').rglob(pattern):
                if file_path.is_file():
                    try:
                        size = file_path.stat().st_size
                        file_path.unlink()
                        freed_space += size
                    except (OSError, IOError):
                        pass
                elif file_path.is_dir() and pattern in ['__pycache__']:
                    try:
                        shutil.rmtree(file_path)
                    except (OSError, IOError):
                        pass
        
        return freed_space / (1024**2)  # Return MB
    
    def emergency_cleanup(self):
        """Perform emergency cleanup when disk is full"""
        print("🚨 Emergency cleanup - disk space critically low!")
        
        # 1. Clean temporary files
        temp_freed = self.cleanup_temporary_files()
        print(f"Cleaned {temp_freed:.1f} MB of temporary files")
        
        # 2. Find and remove old simulation results
        large_dirs = self.find_large_directories(0.1)
        
        for dir_info in large_dirs:
            current_usage = self.get_disk_usage()
            if current_usage['free_gb'] > self.min_free_gb:
                break
                
            path = dir_info['path']
            size_gb = dir_info['size_gb']
            
            print(f"Removing {path} ({size_gb:.1f} GB)")
            try:
                if os.path.isdir(path):
                    shutil.rmtree(path)
                else:
                    os.remove(path)
                print(f"✅ Removed {path}")
            except (OSError, IOError) as e:
                print(f"❌ Failed to remove {path}: {e}")
    
    def check_and_manage_storage(self):
        """Main storage management function"""
        usage = self.get_disk_usage()
        
        print(f"💾 Disk usage: {usage['used_gb']:.1f}/{usage['total_gb']:.1f} GB ({usage['percent_used']:.1f}%)")
        print(f"💾 Free space: {usage['free_gb']:.1f} GB")
        
        if usage['free_gb'] < self.cleanup_threshold_gb:
            print("⚠️  Disk space critically low - starting emergency cleanup")
            self.emergency_cleanup()
            
        elif usage['free_gb'] < self.min_free_gb:
            print("⚠️  Disk space low - consider running backup")
            large_dirs = self.find_large_directories()
            if large_dirs:
                print("\n📁 Large directories found:")
                for dir_info in large_dirs[:5]:
                    print(f"  {dir_info['path']}: {dir_info['size_gb']:.1f} GB")
                print("\nRun: python backup_to_gdrive.py")
        
        else:
            print("✅ Disk space OK")
        
        return usage

def monitor_storage_during_simulation():
    """Monitor storage during simulation with alerts"""
    manager = StorageManager()
    
    while True:
        usage = manager.check_and_manage_storage()
        
        if usage['free_gb'] < manager.cleanup_threshold_gb:
            print("🛑 STOPPING - Disk space critically low!")
            return False
        
        # Check every 5 minutes
        time.sleep(300)

if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='Manage storage for OpenFOAM simulations')
    parser.add_argument('--monitor', action='store_true', help='Monitor storage continuously')
    parser.add_argument('--cleanup', action='store_true', help='Perform cleanup')
    parser.add_argument('--min-free', type=float, default=5.0, help='Minimum free space in GB')
    
    args = parser.parse_args()
    
    manager = StorageManager(min_free_gb=args.min_free)
    
    if args.monitor:
        monitor_storage_during_simulation()
    elif args.cleanup:
        manager.emergency_cleanup()
    else:
        manager.check_and_manage_storage()