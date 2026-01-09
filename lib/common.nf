// lib/common.nf
// Common utility functions for wf-nanoclust

/**
 * Get workflow parameters as JSON string
 */
def getParams() {
    def json = new groovy.json.JsonBuilder(params)
    return json.toPrettyString()
}

/**
 * Parse workflow version from manifest
 */
def getWorkflowVersion() {
    return workflow.manifest.version ?: "unknown"
}

/**
 * Generate timestamp string
 */
def getTimestamp() {
    return new Date().format("yyyy-MM-dd_HH-mm-ss")
}

/**
 * Check if file exists and is readable
 */
def checkFile(String filepath) {
    def f = file(filepath)
    if (!f.exists()) {
        log.error "File not found: ${filepath}"
        return false
    }
    if (!f.canRead()) {
        log.error "File not readable: ${filepath}"
        return false
    }
    return true
}

/**
 * Check if directory exists and is readable
 */
def checkDir(String dirpath) {
    def d = file(dirpath)
    if (!d.exists()) {
        log.error "Directory not found: ${dirpath}"
        return false
    }
    if (!d.isDirectory()) {
        log.error "Not a directory: ${dirpath}"
        return false
    }
    return true
}

/**
 * Convert memory string to bytes
 */
def memoryToBytes(String memStr) {
    def match = (memStr =~ /(\d+(?:\.\d+)?)\s*([KMGTkmgt]?[Bb]?)/)
    if (!match) return 0
    
    def value = match[0][1] as Double
    def unit = match[0][2].toUpperCase()
    
    def multipliers = [
        'B': 1,
        'KB': 1024,
        'MB': 1024 * 1024,
        'GB': 1024 * 1024 * 1024,
        'TB': 1024L * 1024 * 1024 * 1024
    ]
    
    return (value * (multipliers[unit] ?: 1)) as Long
}

/**
 * Format bytes to human readable string
 */
def bytesToHuman(Long bytes) {
    if (bytes < 1024) return "${bytes} B"
    def units = ['KB', 'MB', 'GB', 'TB']
    def idx = 0
    def value = bytes / 1024.0
    
    while (value >= 1024 && idx < units.size() - 1) {
        value /= 1024.0
        idx++
    }
    
    return String.format("%.2f %s", value, units[idx])
}
