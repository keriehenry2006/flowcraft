-- Fix working day calculation for negative Wd values
-- Problem: Wd-2 in July should return 2nd working day from END of June (27 June), not beginning (2 June)
-- Solution: For negative working days, count backwards from end of previous month

CREATE OR REPLACE FUNCTION get_actual_date_for_working_day(wd INTEGER, target_year INTEGER, target_month INTEGER)
RETURNS DATE AS $$
DECLARE
    start_date DATE;
    end_date DATE;
    iter_date DATE;
    working_day_count INTEGER := 0;
    actual_wd INTEGER;
BEGIN
    -- Handle negative working days (previous month, counting backwards from end)
    IF wd < 0 THEN
        actual_wd := ABS(wd);
        IF target_month = 1 THEN
            target_year := target_year - 1;
            target_month := 12;
        ELSE
            target_month := target_month - 1;
        END IF;
        
        -- For negative working days, start from end of month and count backwards
        start_date := DATE (target_year || '-' || target_month || '-01');
        end_date := (start_date + INTERVAL '1 month - 1 day')::DATE;
        iter_date := end_date; -- Start from last day of month
        
        WHILE iter_date >= start_date LOOP
            -- Skip weekends (Saturday = 6, Sunday = 0)
            IF EXTRACT(DOW FROM iter_date) NOT IN (0, 6) THEN
                working_day_count := working_day_count + 1;
                IF working_day_count = actual_wd THEN
                    RETURN iter_date;
                END IF;
            END IF;
            iter_date := iter_date - INTERVAL '1 day'; -- Count backwards
        END LOOP;
        
    ELSE
        -- For positive working days, count forward from start of month
        actual_wd := wd;
        start_date := DATE (target_year || '-' || target_month || '-01');
        end_date := (start_date + INTERVAL '1 month - 1 day')::DATE;
        iter_date := start_date;
        
        WHILE iter_date <= end_date LOOP
            -- Skip weekends (Saturday = 6, Sunday = 0)
            IF EXTRACT(DOW FROM iter_date) NOT IN (0, 6) THEN
                working_day_count := working_day_count + 1;
                IF working_day_count = actual_wd THEN
                    RETURN iter_date;
                END IF;
            END IF;
            iter_date := iter_date + INTERVAL '1 day';
        END LOOP;
    END IF;
    
    RETURN NULL; -- Working day not found
END;
$$ LANGUAGE plpgsql;

-- Test the function
-- Wd-2 in July 2025 should return 27 June 2025 (2nd working day from end of June)
SELECT 
    get_actual_date_for_working_day(-2, 2025, 7) as wd_minus_2_july_2025,
    get_actual_date_for_working_day(2, 2025, 7) as wd_2_july_2025;

-- Expected results:
-- wd_minus_2_july_2025: 2025-06-27 (Friday, 27 June 2025)
-- wd_2_july_2025: 2025-07-02 (Wednesday, 2 July 2025)