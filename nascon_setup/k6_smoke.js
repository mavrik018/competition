// k6 smoke load test against the Selenium hub's status endpoint (inside the
// compose network). Replace the URL with your backend's health route.
import http from 'k6/http';
import { check } from 'k6';

export const options = {
  vus: 5,
  duration: '5s',
  thresholds: { http_req_failed: ['rate<0.01'], http_req_duration: ['p(95)<500'] },
};

export default function () {
  const res = http.get('http://selenium-hub:4444/status');
  check(res, { 'status is 200': (r) => r.status === 200 });
}
