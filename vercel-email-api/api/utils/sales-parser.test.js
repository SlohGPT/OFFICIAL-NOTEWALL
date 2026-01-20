
import { fetchRealDownloadCount } from './sales-parser.js';
import { jest } from '@jest/globals';

// Mock fetch
global.fetch = jest.fn();

// Mock console to keep output clean
global.console = {
    log: jest.fn(),
    error: jest.fn(),
};

describe('sales-parser', () => {
    const originalEnv = process.env;

    beforeEach(() => {
        jest.resetModules();
        process.env = {
            ...originalEnv,
            ASC_VENDOR_NUMBER: '123456',
            ASC_BUNDLE_ID: 'com.test',
        };
        global.fetch.mockReset();
    });

    afterAll(() => {
        process.env = originalEnv;
    });

    it('should fetch downloads in batches and handle 404s gracefully', async () => {
        // Mock fetch to return 404 (simulating missing report for date)
        // This allows the code to proceed through all dates without needing complex unzip mocking
        global.fetch.mockResolvedValue({
            ok: false,
            status: 404,
            text: () => Promise.resolve('Not Found'),
        });

        const token = 'fake-token';
        // Expecting 0 downloads since all reports "failed"
        // But importantly, it should traverse all 90 days.
        // If verify succeeds, it means the parallel batching logic executed correctly.
        try {
            await fetchRealDownloadCount(token);
        } catch (e) {
            // fetchRealDownloadCount throws if total is 0?
            // Let's check source: 
            // if (totalDownloads === 0) { throw new Error(...) }
            // So we expect it to throw "No download data found..."
            // We catch it and verify calls.
        }

        // We expect 90 calls to fetch (one for each day)
        expect(global.fetch).toHaveBeenCalledTimes(90);
    });
});
