# Controller Performance Results

- Run timestamp (UTC): 2026-07-07T20:59:43Z
- Base URL: http://127.0.0.1:8099
- Course ID: course-123
- Iterations (next/previous pairs): 5
- Initial target: <= 2.0s
- Navigation target (mean next): <= 0.150s

## Measurements

- Presentation fetch: 0.004705s
- First slide fetch: 0.001487s
- Initial total (presentation + first slide): 0.006s -> PASS
- Next navigation mean: 0.001s -> PASS
- Next navigation max: 0.002s

## Raw Next Navigation Times (s)

0.001567 0.001412 0.001215 0.001209 0.001269 

