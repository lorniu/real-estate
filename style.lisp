(ql:quickload :css-lite)

(defun abs-pos (div x y w h)
  (css ((div) ((:position "absolute")
	       (:left x) (:top y) (:width w) (:height h)))))