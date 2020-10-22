include("inverse.jl")

MODE = "bfgs_adam_hessian"

make_directory("data/result$MODE")
opt = AdamOptimizer().minimize(loss)

g = [tf.convert_to_tensor(gradients(loss, θ1)); tf.convert_to_tensor(gradients(loss, θ2))]
include("../optimizers.jl")

sess = Session(); init(sess)


B = diagm(0=>ones(length(θ1)+length(θ2)))
G, THETA1, THETA2 = run(sess, [g,θ1, θ2])

# run(sess, loss)
losses0 = Float64[]

for i = 1:300
    _, l = run(sess, [opt, loss])
    @info i, l 
    push!(losses0, l)

    G_, THETA1_, THETA2_ = run(sess, [g,θ1, θ2])


    global G, G_ = G_, G 
    global THETA1, THETA1_ = THETA1_, THETA1 
    global THETA2, THETA2_ = THETA2_, THETA2 
    s = [THETA1 - THETA1_; THETA2 - THETA2_]
    y = G - G_ 
    global B = (I - s*y'/(y'*s)) * B * (I - y*s'/(y'*s)) + s*s'/(y'*s)

end


losses = Optimize!(sess, loss; vars = [θ1, θ2], optimizer = BFGSOptimizer(), max_num_iter=700, B = B)

losses = [losses0; losses]

THETA1, THETA2 = run(sess, [θ1, θ2])

@save "data/result$MODE/data.jld2" THETA1 THETA2 losses

close("all")
semilogy(losses)
savefig("data/result$MODE/loss.png")

E_, nu_ = run(sess, [E, nu])
close("all")
figure(figsize=(10,4))
subplot(121)
visualize_scalar_on_gauss_points(E_, mmesh)
subplot(122)
visualize_scalar_on_gauss_points(nu_, mmesh)
savefig("data/result$MODE/final.png")
