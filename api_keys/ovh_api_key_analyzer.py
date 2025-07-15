#!/usr/bin/env python3
"""
OVH API Key Analyzer
Shows all API keys with valid Application IDs and their expiration dates.
"""

import ovh
import os
import argparse
from dotenv import load_dotenv
from datetime import datetime

def load_ovh_client():
    """Load OVH Client with credentials from .env file."""
    # Load .env file from the same directory
    env_path = os.path.join(os.path.dirname(__file__), '.env')
    load_dotenv(env_path)
    
    endpoint = os.getenv('OVH_ENDPOINT')
    application_key = os.getenv('OVH_APPLICATION_KEY')
    application_secret = os.getenv('OVH_APPLICATION_SECRET')
    consumer_key = os.getenv('OVH_CONSUMER_KEY')
    
    if not all([endpoint, application_key, application_secret, consumer_key]):
        raise ValueError("Missing OVH API credentials in .env file")
    
    return ovh.Client(
        endpoint=endpoint,
        application_key=application_key,
        application_secret=application_secret,
        consumer_key=consumer_key,
    )

def search_credentials_by_appids(client, target_app_ids):
    """Search all credentials for specific application IDs."""
    print(f"Searching for credentials with Application IDs: {', '.join(map(str, target_app_ids))}")
    
    try:
        # Get all credential IDs
        credential_ids = client.get('/me/api/credential')
        print(f"Found: {len(credential_ids)} credentials to search")
    except Exception as e:
        print(f"Error loading credential IDs: {e}")
        return {}
    
    # Dictionary to store results by app_id
    results_by_appid = {app_id: [] for app_id in target_app_ids}
    
    for credential_id in credential_ids:
        try:
            # Get credential details
            credential = client.get(f'/me/api/credential/{credential_id}')
            application_id = credential.get('applicationId')
            
            if application_id in target_app_ids:
                print(f"✓ Found matching Credential ID: {credential_id} for App ID: {application_id}")
                
                # Try to get application details
                try:
                    application = client.get(f'/me/api/application/{application_id}')
                    results_by_appid[application_id].append({
                        'credential': credential,
                        'application': application
                    })
                except ovh.exceptions.ResourceNotFoundError:
                    # Application doesn't exist
                    results_by_appid[application_id].append({
                        'credential': credential,
                        'application': None
                    })
                except Exception:
                    # Other errors
                    results_by_appid[application_id].append({
                        'credential': credential,
                        'application': None
                    })
                
        except Exception as e:
            # Credential errors - silently ignore
            continue
    
    return results_by_appid

def display_appids_search_results(results_by_appid):
    """Display search results for specific application IDs."""
    total_found = sum(len(credentials) for credentials in results_by_appid.values())
    
    print(f"\n{'='*80}")
    print(f"SEARCH RESULTS FOR APPLICATION IDs: {', '.join(map(str, results_by_appid.keys()))}")
    print(f"Found {total_found} matching credential(s) total")
    print(f"{'='*80}")
    
    for app_id, matching_credentials in results_by_appid.items():
        print(f"\n{'='*80}")
        print(f"APPLICATION ID: {app_id} ({len(matching_credentials)} credential(s))")
        print(f"{'='*80}")
        
        if not matching_credentials:
            print("No credentials found with this Application ID.")
            continue
        
        for i, item in enumerate(matching_credentials, 1):
            credential = item['credential']
            application = item['application']
            
            print(f"\n{'-'*60}")
            print(f"#{i} CREDENTIAL ID: {credential.get('credentialId')}")
            print(f"{'-'*60}")
            
            # Credential information
            print("CREDENTIAL DETAILS:")
            print(f"  Created:       {format_datetime(credential.get('creation'))}")
            print(f"  Expires:       {format_datetime(credential.get('expiration'))}")
            print(f"  Last Used:     {format_datetime(credential.get('lastUse'))}")
            print(f"  Status:        {credential.get('status', 'Unknown')}")
            print(f"  Application:   {credential.get('applicationId')}")
            
            # Rules display
            rules = credential.get('rules', [])
            if rules:
                print(f"  Permissions:")
                for rule in rules:
                    method = rule.get('method', 'Unknown')
                    path = rule.get('path', 'Unknown')
                    print(f"    {method} {path}")
            else:
                print(f"  Permissions:   None found")
            
            # Application information
            if application:
                print("\nAPPLICATION DETAILS:")
                print(f"  Name:          {application.get('name', 'Unknown')}")
                print(f"  Description:   {application.get('description', 'No description')}")
                print(f"  Status:        {application.get('status', 'Unknown')}")
            else:
                print("\nAPPLICATION DETAILS:")
                print(f"  Status:        Application not found or inaccessible")

def search_credentials_by_appid(client, target_app_id):
    """Search all credentials for a specific application ID."""
    print(f"Searching for credentials with Application ID: {target_app_id}")
    
    try:
        # Get all credential IDs
        credential_ids = client.get('/me/api/credential')
        print(f"Found: {len(credential_ids)} credentials to search")
    except Exception as e:
        print(f"Error loading credential IDs: {e}")
        return []
    
    matching_credentials = []
    
    for credential_id in credential_ids:
        try:
            # Get credential details
            credential = client.get(f'/me/api/credential/{credential_id}')
            application_id = credential.get('applicationId')
            
            if application_id == target_app_id:
                print(f"✓ Found matching Credential ID: {credential_id}")
                
                # Try to get application details
                try:
                    application = client.get(f'/me/api/application/{application_id}')
                    matching_credentials.append({
                        'credential': credential,
                        'application': application
                    })
                except ovh.exceptions.ResourceNotFoundError:
                    # Application doesn't exist
                    matching_credentials.append({
                        'credential': credential,
                        'application': None
                    })
                except Exception:
                    # Other errors
                    matching_credentials.append({
                        'credential': credential,
                        'application': None
                    })
                
        except Exception as e:
            # Credential errors - silently ignore
            continue
    
    return matching_credentials

def display_appid_search_results(matching_credentials, target_app_id):
    """Display search results for specific application ID."""
    print(f"\n{'='*80}")
    print(f"SEARCH RESULTS FOR APPLICATION ID: {target_app_id}")
    print(f"Found {len(matching_credentials)} matching credential(s)")
    print(f"{'='*80}")
    
    if not matching_credentials:
        print("No credentials found with this Application ID.")
        return
    
    for i, item in enumerate(matching_credentials, 1):
        credential = item['credential']
        application = item['application']
        
        print(f"\n{'-'*60}")
        print(f"#{i} CREDENTIAL ID: {credential.get('credentialId')}")
        print(f"{'-'*60}")
        
        # Credential information
        print("CREDENTIAL DETAILS:")
        print(f"  Created:       {format_datetime(credential.get('creation'))}")
        print(f"  Expires:       {format_datetime(credential.get('expiration'))}")
        print(f"  Last Used:     {format_datetime(credential.get('lastUse'))}")
        print(f"  Status:        {credential.get('status', 'Unknown')}")
        print(f"  Application:   {credential.get('applicationId')}")
        
        # Rules display
        rules = credential.get('rules', [])
        if rules:
            print(f"  Permissions:")
            for rule in rules:
                method = rule.get('method', 'Unknown')
                path = rule.get('path', 'Unknown')
                print(f"    {method} {path}")
        else:
            print(f"  Permissions:   None found")
        
        # Application information
        if application:
            print("\nAPPLICATION DETAILS:")
            print(f"  Name:          {application.get('name', 'Unknown')}")
            print(f"  Description:   {application.get('description', 'No description')}")
            print(f"  Status:        {application.get('status', 'Unknown')}")
        else:
            print("\nAPPLICATION DETAILS:")
            print(f"  Status:        Application not found or inaccessible")

def get_valid_credentials(client):
    """Get all credentials and check if their applications exist."""
    print("Loading all API credentials...")
    
    try:
        # Get all credential IDs
        credential_ids = client.get('/me/api/credential')
        print(f"Found: {len(credential_ids)} credentials")
    except Exception as e:
        print(f"Error loading credential IDs: {e}")
        return []
    
    valid_credentials = []
    
    for credential_id in credential_ids:
        try:
            # Get credential details
            credential = client.get(f'/me/api/credential/{credential_id}')
            application_id = credential.get('applicationId')
            
            if not application_id:
                continue
                
            # Check if application exists
            try:
                application = client.get(f'/me/api/application/{application_id}')
                
                # Only display if application exists
                print(f"✓ Credential ID {credential_id} with valid application: {application.get('name', 'Unknown')}")
                
                valid_credentials.append({
                    'credential': credential,
                    'application': application
                })
                
            except ovh.exceptions.ResourceNotFoundError:
                # Application doesn't exist - silently ignore
                continue
            except Exception as app_error:
                # Other errors - silently ignore
                continue
                
        except Exception as e:
            # Credential errors - silently ignore
            continue
    
    return valid_credentials

def get_orphaned_applications(client, valid_application_ids):
    """Get all applications that have no valid credentials assigned."""
    print("\nChecking for orphaned applications...")
    
    try:
        # Get all application IDs
        application_ids = client.get('/me/api/application')
        print(f"Found: {len(application_ids)} total applications")
    except Exception as e:
        print(f"Error loading application IDs: {e}")
        return []
    
    orphaned_applications = []
    
    for app_id in application_ids:
        if app_id not in valid_application_ids:
            try:
                application = client.get(f'/me/api/application/{app_id}')
                print(f"✗ Orphaned Application ID {app_id}: {application.get('name', 'Unknown')}")
                orphaned_applications.append(application)
            except Exception as e:
                # Application might not exist anymore
                continue
    
    return orphaned_applications

def format_datetime(date_str):
    """Format ISO datetime string for better readability."""
    if not date_str:
        return "Not set"
    
    try:
        dt = datetime.fromisoformat(date_str.replace('Z', '+00:00'))
        return dt.strftime('%d.%m.%Y %H:%M:%S UTC')
    except:
        return date_str

def display_results(valid_credentials):
    """Display the results in a formatted way."""
    print(f"\n{'='*80}")
    print(f"VALID API KEYS ({len(valid_credentials)} found)")
    print(f"{'='*80}")
    
    for i, item in enumerate(valid_credentials, 1):
        credential = item['credential']
        application = item['application']
        
        print(f"\n{'-'*60}")
        print(f"#{i} CREDENTIAL ID: {credential.get('credentialId')}")
        print(f"{'-'*60}")
        
        # Credential information
        print("CREDENTIAL DETAILS:")
        print(f"  Created:       {format_datetime(credential.get('creation'))}")
        print(f"  Expires:       {format_datetime(credential.get('expiration'))}")
        print(f"  Last Used:     {format_datetime(credential.get('lastUse'))}")
        print(f"  Status:        {credential.get('status', 'Unknown')}")
        print(f"  Application:   {credential.get('applicationId')}")
        
        # Rules display
        rules = credential.get('rules', [])
        if rules:
            print(f"  Permissions:")
            for rule in rules:
                method = rule.get('method', 'Unknown')
                path = rule.get('path', 'Unknown')
                print(f"    {method} {path}")
        else:
            print(f"  Permissions:   None found")
        
        # Application information
        print("\nAPPLICATION DETAILS:")
        print(f"  Name:          {application.get('name', 'Unknown')}")
        print(f"  Description:   {application.get('description', 'No description')}")
        print(f"  Status:        {application.get('status', 'Unknown')}")

def display_orphaned_applications(orphaned_applications):
    """Display orphaned applications."""
    if not orphaned_applications:
        print(f"\n{'='*80}")
        print("ORPHANED APPLICATIONS: None found")
        print(f"{'='*80}")
        return
    
    print(f"\n{'='*80}")
    print(f"ORPHANED APPLICATIONS ({len(orphaned_applications)} found)")
    print("Applications without any valid credentials")
    print(f"{'='*80}")
    
    for i, application in enumerate(orphaned_applications, 1):
        print(f"\n{'-'*60}")
        print(f"#{i} APPLICATION ID: {application.get('applicationId')}")
        print(f"{'-'*60}")
        
        print("APPLICATION DETAILS:")
        print(f"  Name:          {application.get('name', 'Unknown')}")
        print(f"  Description:   {application.get('description', 'No description')}")
        print(f"  Status:        {application.get('status', 'Unknown')}")

def main():
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='OVH API Key Analyzer')
    parser.add_argument('--appid', type=int, nargs='+', help='Search for credentials with specific Application ID(s). Can specify multiple IDs separated by spaces.')
    args = parser.parse_args()
    
    try:
        # Load OVH client
        client = load_ovh_client()
        
        if args.appid:
            # Search for specific application ID(s)
            if len(args.appid) == 1:
                # Single app ID - use original function for backward compatibility
                matching_credentials = search_credentials_by_appid(client, args.appid[0])
                display_appid_search_results(matching_credentials, args.appid[0])
            else:
                # Multiple app IDs - use new function
                results_by_appid = search_credentials_by_appids(client, args.appid)
                display_appids_search_results(results_by_appid)
        else:
            # Normal operation - show all valid credentials and orphaned applications
            # Find valid credentials
            valid_credentials = get_valid_credentials(client)
            
            # Collect application IDs that have valid credentials
            valid_application_ids = set()
            for item in valid_credentials:
                valid_application_ids.add(item['credential'].get('applicationId'))
            
            # Display results
            display_results(valid_credentials)
            
            # Find and display orphaned applications
            orphaned_applications = get_orphaned_applications(client, valid_application_ids)
            display_orphaned_applications(orphaned_applications)
        
    except Exception as e:
        print(f"Error: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())
