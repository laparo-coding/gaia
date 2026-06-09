# Controller Performance Results

- Run timestamp (UTC): 2026-06-06T18:24:40Z
- Base URL: http://127.0.0.1:8080
- Course ID: course-123
- Iterations (next/previous pairs): 5
- Initial target: <= 2.0s
- Navigation target (mean next): <= 0.150s

## Measurements

- Presentation fetch: 0.021478s
- First slide fetch: 0.003498s
- Initial total (presentation + first slide): 0.025s -> PASS
- Next navigation mean: 0.005s -> PASS
- Next navigation max: 0.006s

## Raw Next Navigation Times (s)

0.003894 0.005095 0.005575 0.004787 0.003738 

