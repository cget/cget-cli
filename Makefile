default:
	mkdir -p bin && cd bin && cmake -DCMAKE_BUILD_TYPE=Debug .. && cmake --build . --target install

clean:
	rm -rf bin && rm -rf bin_arm
