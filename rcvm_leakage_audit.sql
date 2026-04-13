/* PROJECT: OSF RCVM Analytics
   ENGINEER: Mari Stricklin
   PURPOSE: Identify Revenue Leakage ($118K) and Verification Bottlenecks 
*/

-- 1. IDENTIFY THE BOTTLENECK: Measuring verification lag time per vendor
SELECT 
    Vendor_Name,
    COUNT(Claim_ID) AS Total_Claims,
    AVG(DATEDIFF(day, Date_Submitted, Date_Verified)) AS Avg_Days_To_Verify
FROM [Fabric_Warehouse].[dbo].[Claims_Staging]
GROUP BY Vendor_Name
ORDER BY Avg_Days_To_Verify DESC;

-- 2. QUANTIFY THE LEAKAGE: Three-Way Match (Claims vs. Payments)
CREATE OR ALTER VIEW gold.vw_Revenue_Leakage_Audit AS
SELECT 
    c.Claim_ID,
    c.Vendor_Name,
    c.Billed_Amount,
    ISNULL(p.Paid_Amount, 0) AS Paid_Amount,
    (c.Billed_Amount - ISNULL(p.Paid_Amount, 0)) AS Leakage_Amount,
    CASE 
        WHEN v.Date_Verified IS NULL THEN 'Bottleneck: Missing Verification'
        WHEN DATEDIFF(day, c.Date_Submitted, v.Date_Verified) > 5 THEN 'Bottleneck: High Latency'
        ELSE 'Process Healthy'
    END AS Operational_Status
FROM [dbo].[Claims] c
LEFT JOIN [dbo].[Payments] p ON c.Claim_ID = p.Claim_ID
LEFT JOIN [dbo].[Verifications] v ON c.Claim_ID = v.Claim_ID
WHERE (c.Billed_Amount - ISNULL(p.Paid_Amount, 0)) > 0;
