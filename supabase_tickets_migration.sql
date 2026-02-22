-- ============================================
-- SUPABASE SETUP FOR JIRA TICKETS TRACKING
-- ============================================
-- Run these queries in your Supabase SQL Editor
-- Dashboard → SQL Editor → New Query
-- ============================================

-- ============================================
-- 1. CREATE THE JIRA_TICKETS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS jira_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_key TEXT NOT NULL UNIQUE,  -- Jira ticket key (e.g., "HYMNS-123")
    ticket_url TEXT NOT NULL,
    song_type TEXT NOT NULL,  -- 'Hymn' or 'Keerthane'
    song_number INTEGER NOT NULL,
    song_title TEXT NOT NULL,
    description TEXT,  -- User-provided description
    app_version TEXT,
    jira_status TEXT DEFAULT 'Open',  -- Status from Jira (Open, Work In Progress, Pending, Done)
    jira_status_id TEXT,  -- Jira status ID
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    -- For registered users
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    -- For unregistered users - use device identifier
    device_id TEXT,  -- Unique device identifier stored in SharedPreferences
    -- Index for faster queries
    CONSTRAINT jira_tickets_user_or_device CHECK (
        (user_id IS NOT NULL) OR (device_id IS NOT NULL)
    )
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_jira_tickets_user_id ON jira_tickets(user_id);
CREATE INDEX IF NOT EXISTS idx_jira_tickets_device_id ON jira_tickets(device_id);
CREATE INDEX IF NOT EXISTS idx_jira_tickets_ticket_key ON jira_tickets(ticket_key);
CREATE INDEX IF NOT EXISTS idx_jira_tickets_created_at ON jira_tickets(created_at DESC);

-- ============================================
-- 2. ENABLE ROW LEVEL SECURITY (RLS)
-- ============================================

ALTER TABLE jira_tickets ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 3. RLS POLICIES FOR JIRA_TICKETS TABLE
-- ============================================

-- Policy 1: Users can view their own tickets (by user_id)
CREATE POLICY "Users can view their own tickets"
ON jira_tickets
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Policy 2: Users can insert their own tickets
CREATE POLICY "Users can insert their own tickets"
ON jira_tickets
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Policy 3: Public can view tickets by device_id (for unregistered users)
-- Note: This requires device_id to be passed in the query
-- We'll handle this in the service layer

-- Policy 4: Public can insert tickets with device_id (for unregistered users)
CREATE POLICY "Public can insert tickets with device_id"
ON jira_tickets
FOR INSERT
TO public
WITH CHECK (device_id IS NOT NULL AND user_id IS NULL);

-- Policy 5: Public can view tickets by device_id (for unregistered users)
CREATE POLICY "Public can view tickets by device_id"
ON jira_tickets
FOR SELECT
TO public
USING (device_id IS NOT NULL);

-- Policy 6: Authenticated users can update their own tickets
CREATE POLICY "Users can update their own tickets"
ON jira_tickets
FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy 7: Public can update tickets by device_id (for unregistered users)
CREATE POLICY "Public can update tickets by device_id"
ON jira_tickets
FOR UPDATE
TO public
USING (device_id IS NOT NULL AND user_id IS NULL)
WITH CHECK (device_id IS NOT NULL AND user_id IS NULL);

-- ============================================
-- 4. FUNCTION TO UPDATE UPDATED_AT TIMESTAMP
-- ============================================

CREATE OR REPLACE FUNCTION update_jira_tickets_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER update_jira_tickets_updated_at
    BEFORE UPDATE ON jira_tickets
    FOR EACH ROW
    EXECUTE FUNCTION update_jira_tickets_updated_at();

-- ============================================
-- 5. VERIFY SETUP (Optional - run to check)
-- ============================================

-- Check table exists
SELECT * FROM jira_tickets LIMIT 5;

-- Check policies
SELECT policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename = 'jira_tickets';
