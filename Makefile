default:
	mkdir -p bin && cd bin && cmake -DCMAKE_BUILD_TYPE=Debug .. && cmake --build .

clean:
	rm -rf bin && rm -rf bin_arm
