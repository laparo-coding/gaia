# Controller Performance Results

- Run timestamp (UTC): 2026-05-31T22:17:53Z
- Base URL: http://127.0.0.1:8080
- Course ID: course-123
- Iterations (next/previous pairs): 10
- Initial target: <= 2.0s
- Navigation target (mean next): <= 0.150s

## Measurements

- Presentation fetch: 0.003269s
- First slide fetch: 0.003017s
- Initial total (presentation + first slide): 0.006s -> PASS
- Next navigation mean: 0.003s -> PASS
- Next navigation max: 0.003s

## Raw Next Navigation Times (s)

0.002965 0.002826 0.003419 0.002863 0.002806 0.002793 0.003002 0.002832 0.002879 0.003086 

