import re
import sys

class VowpalWabbitData:

    ranking = True

    def __init__(self, ranking=False):
        self.ranking = ranking

    def read(self, input_file):
        X = []
        Y = []
        losses = []
        line_num = 0
        for line in input_file:
            line.rstrip("\n")
            
            # empty line indicates a new instance if ranking=1
            if re.search("^\s+$", line):
                if self.ranking:
                    Y += [ x <= min(losses) for x in losses ]
                    losses = []
                continue
                    
            parts = line.split("|")
            
            # process the label part
            label_part = parts.pop(0)
            (label_loss, tag) = label_part.split()
            (label, loss) = label_loss.split(":")
            if self.ranking:
                losses.append(loss)
            else:
                Y.append(label)

            # process namespaces with features
            all_feat_hash = {}
            for ns_feats in parts:
                feats = ns_feats.split()
                
                # identify the namespace
                ns = ''
                if not ns_feats.startswith(' '):
                    ns = feats.pop(0)

                # extract a feat hash
                feats_name_valued = [ i+'=1' if not re.search("=", i) else i for i in feats ]
                feat_hash = { (ns+"^"+k):v for (k,v) in (tuple(s.split("=",1)) for s in feats_name_valued) }
                all_feat_hash.update(feat_hash)

            X.append(all_feat_hash)

            line_num += 1
            if line_num % 10000 == 0:
                print >> sys.stderr, "Number of lines read: " + str(line_num)
        
        return (X, Y)
