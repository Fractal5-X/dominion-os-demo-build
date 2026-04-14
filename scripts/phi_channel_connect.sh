#!/bin/bash
# PHI Channel Connect SaaS Service Integration
# Continuous monitoring and injection for Fractal5 Solutions Inc communication channels

set -e

# Configuration
CHANNELS_CONFIG="data/channel_connect_config.json"
LOG_FILE="logs/channel_connect.log"
PID_FILE="data/channel_connect.pid"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local line="$timestamp [$level] $message"

    printf '%s\n' "$line" >> "$LOG_FILE"
    if [ -t 1 ]; then
        printf '%b%s%b [%s] %s\n' "$BLUE" "$timestamp" "$NC" "$level" "$message"
    fi
}

# Health check function
health_check() {
    log "INFO" "Running Channel Connect health check"
    
    # Check configuration file
    if [ ! -f "$CHANNELS_CONFIG" ]; then
        log "ERROR" "Configuration file missing: $CHANNELS_CONFIG"
        return 1
    fi
    
    # Validate JSON configuration
    if ! jq empty "$CHANNELS_CONFIG" 2>/dev/null; then
        log "ERROR" "Invalid JSON in configuration file"
        return 1
    fi
    
    # Check log file permissions
    if [ ! -w "$LOG_FILE" ]; then
        log "ERROR" "Cannot write to log file: $LOG_FILE"
        return 1
    fi
    
    # Check data directory
    if [ ! -d "data" ]; then
        log "ERROR" "Data directory missing"
        return 1
    fi
    
    log "INFO" "Health check passed"
    return 0
}

# Security hardening function
harden_security() {
    log "INFO" "Applying security hardening"
    
    # Set restrictive permissions on config files
    chmod 600 "$CHANNELS_CONFIG" 2>/dev/null || true
    chmod 600 "$PID_FILE" 2>/dev/null || true
    
    # Ensure log files are not world-readable
    chmod 640 "$LOG_FILE" 2>/dev/null || true
    
    log "INFO" "Security hardening applied"
}

# Rate limiting function
check_rate_limit() {
    local channel_name=$1
    local rate_limit_file="data/${channel_name}_rate_limit"
    
    # Simple rate limiting - max 10 requests per minute per channel
    local current_time=$(date +%s)
    local window_start=$((current_time - 60))
    
    # Clean old entries
    if [ -f "$rate_limit_file" ]; then
        sed -i "/^[0-9]\{10,\}$/d" "$rate_limit_file" 2>/dev/null || true
        awk "\$1 > $window_start" "$rate_limit_file" > "${rate_limit_file}.tmp" 2>/dev/null || true
        mv "${rate_limit_file}.tmp" "$rate_limit_file" 2>/dev/null || true
    fi
    
    # Count requests in current window
    local request_count=$(wc -l < "$rate_limit_file" 2>/dev/null || echo "0")
    
    if [ "$request_count" -ge 10 ]; then
        log "WARN" "Rate limit exceeded for $channel_name"
        return 1
    fi
    
    # Record this request
    echo "$current_time" >> "$rate_limit_file"
    return 0
}

# Create configuration if not exists
create_config() {
    if [ ! -f "$CHANNELS_CONFIG" ]; then
        log "INFO" "Creating channel configuration..."
        mkdir -p data logs

        cat > "$CHANNELS_CONFIG" << 'EOF'
{
  "service_name": "Channel Connect SaaS",
  "description": "Continuous monitoring and content injection for Fractal5 Solutions Inc marketing channels",
  "channels": [
    {
      "name": "Squarespace",
      "type": "website",
      "url": "https://www.fractal5solutions.com",
      "monitoring": {
        "check_interval": 300,
        "monitor_content": true,
        "monitor_traffic": true,
        "monitor_analytics": true,
        "google_analytics": {
          "gtm_container_id": "GTM-KMJJQX55",
          "track_pageviews": true,
          "track_events": true
        }
      },
      "injection": {
        "enabled": true,
        "content_types": ["blog_posts", "updates", "html_pages"],
        "api_endpoint": "https://api.squarespace.com/1.0/commerce/orders",
        "html_prep_enabled": true,
        "css_cannon_enabled": true
      }
    },
    {
      "name": "Facebook",
      "type": "social",
      "url": "https://www.facebook.com/profile.php?id=61572428791801",
      "monitoring": {
        "check_interval": 180,
        "monitor_mentions": true,
        "monitor_engagement": true,
        "monitor_page_insights": true
      },
      "injection": {
        "enabled": true,
        "content_types": ["posts", "stories", "images"],
        "api_endpoint": "https://graph.facebook.com/v18.0/me/feed",
        "page_id": "61572428791801"
      }
    },
    {
      "name": "Twitter",
      "type": "social",
      "url": "https://x.com/Fractal5X",
      "monitoring": {
        "check_interval": 120,
        "monitor_mentions": true,
        "monitor_hashtags": ["#Fractal5", "#SovereignAI", "#DominionOS"],
        "monitor_engagement": true,
        "monitor_followers": true
      },
      "injection": {
        "enabled": true,
        "content_types": ["tweets", "threads", "images"],
        "api_endpoint": "https://api.twitter.com/2/tweets",
        "username": "Fractal5X"
      }
    },
    {
      "name": "YouTube",
      "type": "video",
      "url": "https://www.youtube.com/@Fractal5Solutions",
      "monitoring": {
        "check_interval": 600,
        "monitor_videos": true,
        "monitor_comments": true,
        "monitor_subscribers": true,
        "monitor_views": true
      },
      "injection": {
        "enabled": true,
        "content_types": ["videos", "shorts", "live_streams", "thumbnails"],
        "api_endpoint": "https://www.googleapis.com/youtube/v3/videos",
        "channel_handle": "@Fractal5Solutions"
      }
    },
    {
      "name": "Substack",
      "type": "newsletter",
      "url": "https://matthewburbidge.substack.com/",
      "monitoring": {
        "check_interval": 3600,
        "monitor_subscribers": true,
        "monitor_posts": true,
        "monitor_comments": true,
        "monitor_engagement": true
      },
      "injection": {
        "enabled": true,
        "content_types": ["newsletter_posts", "updates", "paid_content"],
        "api_endpoint": "https://substack.com/api/v1/posts",
        "author": "matthewburbidge"
      }
    }
  ],
  "monitoring_settings": {
    "global_check_interval": 300,
    "alert_thresholds": {
      "engagement_drop": 0.2,
      "traffic_drop": 0.15,
      "mention_spike": 2.0
    },
    "alert_channels": ["email", "slack"]
  },
  "injection_settings": {
    "content_schedule": {
      "facebook": "0 */4 * * *",
      "twitter": "0 */2 * * *",
      "youtube": "0 12 * * 1,4",
      "substack": "0 9 * * 2,5",
      "website": "0 10 * * 1,3,5"
    },
    "content_sources": [
      "phi_ai_content_generator",
      "market_intelligence",
      "product_updates",
      "customer_stories"
    ]
  },
  "dominion_integration": {
    "phi_ai_agent": "phi_commercial_ai_agent.sh",
    "monitoring_endpoint": "http://localhost:8081/api/monitor",
    "content_api": "http://localhost:5000/api/content"
  }
}
EOF
        log "INFO" "Channel configuration created"
    fi
}

# Monitor a specific channel
monitor_channel() {
    local channel_name=$1
    local channel_config=$2

    log "INFO" "Monitoring channel: $channel_name"

    # Check rate limiting
    if ! check_rate_limit "$channel_name"; then
        log "WARN" "Skipping $channel_name due to rate limiting"
        return
    fi

    # Extract monitoring settings
    local check_interval=$(echo "$channel_config" | jq -r '.monitoring.check_interval')
    local url=$(echo "$channel_config" | jq -r '.url')

    # Basic monitoring - check if URL is accessible
    if curl -s --head --max-time 10 "$url" > /dev/null 2>&1; then
        log "INFO" "$channel_name - URL accessible"
    else
        log "WARN" "$channel_name - URL not accessible"
    fi

    # Enhanced monitoring based on channel type
    case $channel_name in
        "Squarespace")
            # Monitor website with Google Analytics
            log "INFO" "Monitoring Squarespace website content, traffic, and GTM-KMJJQX55 analytics..."
            # Check for Google Analytics container
            if curl -s "$url" | grep -q "GTM-KMJJQX55"; then
                log "INFO" "Google Analytics GTM-KMJJQX55 detected and active"
            else
                log "WARN" "Google Analytics GTM-KMJJQX55 not found on page"
            fi
            ;;
        "Facebook")
            # Monitor Facebook page
            log "INFO" "Monitoring Facebook page engagement and insights..."
            ;;
        "Twitter")
            # Monitor Twitter/X account
            log "INFO" "Monitoring Twitter/X mentions, hashtags, and engagement..."
            ;;
        "YouTube")
            # Monitor YouTube channel
            log "INFO" "Monitoring YouTube videos, comments, subscribers, and views..."
            ;;
        "Substack")
            # Monitor Substack newsletter
            log "INFO" "Monitoring Substack subscribers, posts, and engagement..."
            ;;
    esac
}

# Inject content to a channel
inject_content() {
    local channel_name=$1
    local channel_config=$2

    log "INFO" "Injecting content to: $channel_name"

    # Check if injection is enabled
    local enabled=$(echo "$channel_config" | jq -r '.injection.enabled')
    if [ "$enabled" != "true" ]; then
        log "INFO" "$channel_name - Injection disabled"
        return
    fi

    # Placeholder for content injection
    case $channel_name in
        "Facebook")
            log "INFO" "Posting to Facebook..."
            # API call would go here
            ;;
        "Twitter")
            log "INFO" "Posting to Twitter..."
            # API call would go here
            ;;
        "YouTube")
            log "INFO" "Uploading to YouTube..."
            # API call would go here
            ;;
        "Substack")
            log "INFO" "Publishing to Substack..."
            # API call would go here
            ;;
        "Squarespace"|"Fractal5 Solutions Website")
            log "INFO" "Updating website content..."
            # CMS update would go here
            ;;
    esac
}

# Main monitoring loop
monitor_loop() {
    log "INFO" "Starting channel monitoring loop"

    while true; do
        # Load configuration
        if [ ! -f "$CHANNELS_CONFIG" ]; then
            log "ERROR" "Configuration file not found: $CHANNELS_CONFIG"
            sleep 60
            continue
        fi

        # Get channels
        local channels=$(jq -c '.channels[]' "$CHANNELS_CONFIG")

        # Monitor each channel
        echo "$channels" | while read -r channel; do
            local name=$(echo "$channel" | jq -r '.name')
            monitor_channel "$name" "$channel"
        done

        # Wait before next check
        local interval=$(jq -r '.monitoring_settings.global_check_interval' "$CHANNELS_CONFIG")
        sleep "$interval"
    done
}

# Main injection loop
injection_loop() {
    log "INFO" "Starting content injection loop"

    while true; do
        # Load configuration
        if [ ! -f "$CHANNELS_CONFIG" ]; then
            log "ERROR" "Configuration file not found: $CHANNELS_CONFIG"
            sleep 60
            continue
        fi

        # Get channels
        local channels=$(jq -c '.channels[]' "$CHANNELS_CONFIG")

        # Inject to each channel based on schedule
        echo "$channels" | while read -r channel; do
            local name=$(echo "$channel" | jq -r '.name')
            inject_content "$name" "$channel"
        done

        # Wait before next injection cycle
        sleep 3600  # Check every hour
    done
}

# Start service
start_service() {
    log "INFO" "Starting Channel Connect SaaS Service"

    # Run health check
    if ! health_check; then
        log "ERROR" "Health check failed - aborting startup"
        exit 1
    fi
    
    # Apply security hardening
    harden_security

    # Create PID file
    echo $$ > "$PID_FILE"

    # Start monitoring in background
    monitor_loop &
    MONITOR_PID=$!

    # Start injection in background
    injection_loop &
    INJECTION_PID=$!

    log "INFO" "Service started - Monitor PID: $MONITOR_PID, Injection PID: $INJECTION_PID"

    # Wait for processes
    wait
}

# Stop service
stop_service() {
    log "INFO" "Stopping Channel Connect SaaS Service"

    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        kill -TERM "$pid" 2>/dev/null || true
        rm -f "$PID_FILE"
        log "INFO" "Service stopped"
    else
        log "WARN" "PID file not found"
    fi
}

# Status check
status_service() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo -e "${GREEN}✓ Channel Connect SaaS Service is running${NC}"
        echo "PID: $(cat "$PID_FILE")"
        return 0
    else
        echo -e "${RED}✗ Channel Connect SaaS Service is not running${NC}"
        return 1
    fi
}

# Main function
main() {
    case "${1:-start}" in
        "start")
            create_config
            start_service
            ;;
        "stop")
            stop_service
            ;;
        "status")
            status_service
            ;;
        "restart")
            stop_service
            sleep 2
            start_service
            ;;
        "monitor")
            create_config
            monitor_loop
            ;;
        "inject")
            create_config
            injection_loop
            ;;
        *)
            echo "Usage: $0 {start|stop|status|restart|monitor|inject}"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
