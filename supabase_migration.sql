-- Migration script to add song_number column to christmas_carols table
-- Run this in your Supabase SQL Editor

-- Add song_number column (nullable text field)
ALTER TABLE christmas_carols 
ADD COLUMN IF NOT EXISTS song_number TEXT;

-- Add comment to the column
COMMENT ON COLUMN christmas_carols.song_number IS 'Optional song number for easy searching (e.g., "1", "25", "A1")';

-- Create an index for faster searching by song number
CREATE INDEX IF NOT EXISTS idx_christmas_carols_song_number 
ON christmas_carols(song_number);

-- Update RLS policies if needed (song_number is readable by everyone, writable by authenticated users)
-- The existing RLS policies should already cover this since song_number is just another column
-- But if you need to ensure it's included, you can verify your existing policies

-- Example: If you want to allow searching by song_number in RLS policies:
-- (This is usually not needed as RLS policies apply to the whole row, not individual columns)
-- But if you have specific policies, make sure they don't exclude song_number

