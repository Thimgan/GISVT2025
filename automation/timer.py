from datetime import datetime
import os
from apscheduler.schedulers.blocking import BlockingScheduler

def tick():    
    print('Tick! The time is: %s' % datetime.now())

if __name__ == '__main__':
    scheduler = BlockingScheduler()
    scheduler.add_job(tick, 'interval', seconds = 3)
    print('Press Ctrl+C to exit')
    
    try:
        scheduler.start()
    except(KeyboardInterrupt, SystemExit):
        pass