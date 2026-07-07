# Controller Performance Results

- Run timestamp (UTC): 2026-07-07T21:04:16Z
- Base URL: http://127.0.0.1:8080
- Course ID: course-123
- Iterations (next/previous pairs): 5
- Initial target: <= 2.0s
- Navigation target (mean next): <= 0.150s

## Measurements

- Presentation fetch: 0.007292s
- First slide fetch: 0.002969s
- Initial total (presentation + first slide): 0.010s -> PASS
- Next navigation mean: 0.003s -> PASS
- Next navigation max: 0.003s

## Raw Next Navigation Times (s)

0.003188 0.002819 0.002705 0.002641 0.002777 

