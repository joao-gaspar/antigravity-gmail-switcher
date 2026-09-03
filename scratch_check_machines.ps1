$res = Invoke-RestMethod -Uri "https://antigravity-gmail-switcher.vercel.app/api/sync" -Method POST -Body "{}" -ContentType "application/json"
$res.machines | Format-Table machine_id, hostname, active_email, last_seen
