#!/usr/bin/env python3
"""
Local Web Server for OpenFOAM Visualization
Starts a local HTTP server to serve the HTML visualization files
"""

import http.server
import socketserver
import webbrowser
import os
from pathlib import Path

def start_server(port=8000):
    """Start local HTTP server for visualization"""
    
    # Change to project directory
    project_dir = Path('/Users/takeuchidaiki/research/stepB_project')
    os.chdir(project_dir)
    
    print(f"🌍 Starting web server at http://localhost:{port}")
    print(f"📁 Serving files from: {project_dir}")
    print()
    print("Available viewers:")
    print(f"• Advanced Viewer:  http://localhost:{port}/real_data_web_viewer.html")
    print(f"• Simple Viewer:    http://localhost:{port}/web_visualization.html")
    print(f"• Original Viewer:  http://localhost:{port}/openfoam_web_viewer.html")
    print()
    print("Press Ctrl+C to stop the server")
    print("-" * 60)
    
    # Create HTTP server
    handler = http.server.SimpleHTTPRequestHandler
    
    try:
        with socketserver.TCPServer(("", port), handler) as httpd:
            print(f"✅ Server running on port {port}")
            
            # Auto-open the main viewer in browser
            viewer_url = f"http://localhost:{port}/real_data_web_viewer.html"
            webbrowser.open(viewer_url)
            print(f"🚀 Opening {viewer_url} in your browser...")
            
            # Start serving
            httpd.serve_forever()
            
    except KeyboardInterrupt:
        print("\n👋 Server stopped by user")
    except OSError as e:
        if "Address already in use" in str(e):
            print(f"❌ Port {port} is already in use. Trying port {port + 1}...")
            start_server(port + 1)
        else:
            print(f"❌ Error starting server: {e}")

if __name__ == "__main__":
    start_server()