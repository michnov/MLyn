from collections import Counter

class Baseline:

    class_freqs = None
    best_class = None

    def fit(self, X, y):
        self.class_freqs = Counter(y)
        (self.best_class, count) = self.class_freqs.most_common(1)[0]

    def predict(self, x):
        return self.best_class 
    
    def predict_proba(self, x):
        total = sum(self.class_freqs.values())
        norm = {key:(float(count) / total) for (key,count) in self.class_freqs.items()}
        return [[v for (k,v) in sorted(norm.items(), key=lambda (k, v): k)]]

    def score(self, X, y):
        scores = [ 1 if y_val == self.best_class else 0 for y_val in y ]
        print sum(scores)
        print len(y)
        return float(sum(scores)) / float(len(y))
