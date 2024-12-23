from queue import PriorityQueue


class MaxPriorityQueue(PriorityQueue):

    def __init__(self):
        PriorityQueue.__init__(self)
        self.reverse = -1


    def put(self, priority, data):
        PriorityQueue.put(self, (self.reverse * priority, data))


    def get(self, *args, **kwargs):
        priority, data = PriorityQueue.get(self, *args, **kwargs)
        return self.reverse * priority, data

