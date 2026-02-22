-- ============================================
-- SUPABASE SETUP FOR CHRISTMAS CAROLS FEATURE
-- ============================================
-- Run these queries in your Supabase SQL Editor
-- Dashboard → SQL Editor → New Query
-- ============================================

-- ============================================
-- 1. CREATE THE CHRISTMAS_CAROLS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS christmas_carols (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    church_name TEXT NOT NULL,
    lyrics TEXT,
    pdf TEXT,  -- URL to the PDF in storage
    pdf_pages JSONB,  -- Optional: pre-rendered page images
    transpose INTEGER DEFAULT 0,
    scale TEXT DEFAULT 'C Major',
    created_by_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_christmas_carols_created_at ON christmas_carols(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_christmas_carols_user ON christmas_carols(created_by_user_id);


-- ============================================
-- 2. ENABLE ROW LEVEL SECURITY (RLS)
-- ============================================

ALTER TABLE christmas_carols ENABLE ROW LEVEL SECURITY;


-- ============================================
-- 3. RLS POLICIES FOR CHRISTMAS_CAROLS TABLE
-- ============================================

-- Policy 1: PUBLIC READ - Everyone can view ALL carols (no auth required)
CREATE POLICY "Anyone can view all carols"
ON christmas_carols
FOR SELECT
TO public
USING (true);

-- Policy 2: INSERT - Only authenticated users can add new carols
CREATE POLICY "Authenticated users can add carols"
ON christmas_carols
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = created_by_user_id);

-- Policy 3: UPDATE - Users can ONLY update their OWN carols
CREATE POLICY "Users can update only their own carols"
ON christmas_carols
FOR UPDATE
TO authenticated
USING (auth.uid() = created_by_user_id)
WITH CHECK (auth.uid() = created_by_user_id);

-- Policy 4: DELETE - Users can ONLY delete their OWN carols
CREATE POLICY "Users can delete only their own carols"
ON christmas_carols
FOR DELETE
TO authenticated
USING (auth.uid() = created_by_user_id);


-- ============================================
-- 4. CREATE STORAGE BUCKET FOR PDFs
-- ============================================
-- Note: You need to create the bucket via Dashboard first:
-- Storage → New Bucket → Name: "carol-pdfs" → Public bucket: ON

-- Or use this SQL (if your Supabase version supports it):
INSERT INTO storage.buckets (id, name, public)
VALUES ('carol-pdfs', 'carol-pdfs', true)
ON CONFLICT (id) DO NOTHING;


-- ============================================
-- 5. STORAGE POLICIES FOR PDF BUCKET
-- ============================================

-- Policy 1: PUBLIC READ - Everyone can view/download PDFs
CREATE POLICY "Public can view carol PDFs"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'carol-pdfs');

-- Policy 2: INSERT - Authenticated users can upload PDFs
CREATE POLICY "Authenticated users can upload PDFs"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'carol-pdfs');

-- Policy 3: UPDATE - Users can update their own PDFs (by filename pattern)
CREATE POLICY "Users can update their own PDFs"
ON storage.objects
FOR UPDATE
TO authenticated
USING (bucket_id = 'carol-pdfs');

-- Policy 4: DELETE - Users can delete their own PDFs
CREATE POLICY "Users can delete their own PDFs"
ON storage.objects
FOR DELETE
TO authenticated
USING (bucket_id = 'carol-pdfs');


-- ============================================
-- 6. APP CONFIG TABLE (for remote feature flags)
-- ============================================

CREATE TABLE IF NOT EXISTS app_config (
    id SERIAL PRIMARY KEY,
    key TEXT UNIQUE NOT NULL,
    value JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

-- Everyone can read config
CREATE POLICY "Anyone can read app config"
ON app_config
FOR SELECT
TO public
USING (true);

-- Insert the Christmas mode flag (set to 1 to enable, 0 to disable)
INSERT INTO app_config (key, value)
VALUES ('is_christmas_time', '1')
ON CONFLICT (key) DO UPDATE SET value = '1', updated_at = NOW();


-- ============================================
-- 7. VERIFY SETUP (Optional - run to check)
-- ============================================

-- Check table exists
SELECT * FROM christmas_carols LIMIT 5;

-- Check config
SELECT * FROM app_config;

-- Check policies on christmas_carols
SELECT policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename = 'christmas_carols';


-- ============================================
-- QUICK REFERENCE - PERMISSION SUMMARY
-- ============================================
-- 
-- christmas_carols table:
-- ┌─────────────┬───────────────────┬────────────────────┐
-- │ Action      │ Who Can Do It     │ Condition          │
-- ├─────────────┼───────────────────┼────────────────────┤
-- │ SELECT/View │ Everyone          │ No restrictions    │
-- │ INSERT/Add  │ Authenticated     │ Must set own ID    │
-- │ UPDATE/Edit │ Authenticated     │ Only own carols    │
-- │ DELETE      │ Authenticated     │ Only own carols    │
-- └─────────────┴───────────────────┴────────────────────┘
--
-- carol-pdfs storage:
-- ┌─────────────┬───────────────────┬────────────────────┐
-- │ Action      │ Who Can Do It     │ Condition          │
-- ├─────────────┼───────────────────┼────────────────────┤
-- │ View/Read   │ Everyone          │ No restrictions    │
-- │ Upload      │ Authenticated     │ Any file           │
-- │ Delete      │ Authenticated     │ Any file (*)       │
-- └─────────────┴───────────────────┴────────────────────┘
-- (*) App-level code ensures only owner can delete
--
-- ============================================

