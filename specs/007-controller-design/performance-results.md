# Controller Performance Results

- Run timestamp (UTC): 2026-05-31T22:09:40Z
- Base URL: http://127.0.0.1:8099
- Course ID: course-123
- Iterations (next/previous pairs): 10
- Initial target: <= 2.0s
- Navigation target (mean next): <= 0.150s

## Measurements

- Presentation fetch: 0.001458s
- First slide fetch: 0.001050s
- Initial total (presentation + first slide): 0.003s -> PASS
- Next navigation mean: 0.001s -> PASS
- Next navigation max: 0.002s

## Raw Next Navigation Times (s)

0.000901 0.000921 0.001000 0.001007 0.000974 0.000885 0.001101 0.001009 0.000971 0.001907 

